// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "@goplugin/contracts/src/v0.6/vendor/Ownable.sol";
import "@goplugin/contracts/src/v0.6/PluginClient.sol";
import "./IXRC20.sol";

contract MultiPlinsure is PluginClient, Ownable {

    enum InsurancePeriod {
        TESTNOW,
        MONTH3,
        MONTH6,
        MONTH9,
        MONTH12
    }

    enum Status {
        INITIATED,
        RELEASED
    }

    enum TokenType {
        NATIVE,
        PLI,
        STORX,
        WADZ
    }
    // Insurance Structures////
    uint256 public constant ORACLE_PAYMENT = 0.01 * 10 ** 18;
    uint256 public productid;
    uint256 public liquidityPool = 0;
    uint256 private _unlockDate;
    address public _oracleContractAddr;
    address public contractowner;
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    string public _jobId;

    struct ProductInfo {
        uint256 prodId;  
        uint256 price;    
        uint256 payoutMultiplier;
        TokenType token; 
    }
    
    struct PolicyDetails {
        address payable policyHolder;
        string  policyHash;
        uint256 productId;
        uint256 payableAmount;
        string latlong;         
        bool paid;
        address tokenAddress;
        uint256 tokenType;
        uint256 unlockOn;
        Status policystatus;
   }
    
    mapping(uint256 => ProductInfo) public products;
    mapping(bytes32 => PolicyDetails) public claims; 
    mapping(address => bytes32) public claimRequest;    
    mapping(address => mapping(string => PolicyDetails)) public policies;
    mapping(address => string[]) policyIndex;

    event buyPolicyEvent(string _policyAddress, uint256 _productId, string _latlong);
    event submitMyClaimLog(string _policyAddress);
    event claimPolicySuccessful(string _policyAddress);
    event claimPolicyUnsuccessful(string _policyAddress);
    
    constructor(address _pli, address _oracleaddress,string memory _jobid) public Ownable() {
        setPluginToken(_pli);
        _oracleContractAddr = _oracleaddress;
        _jobId  = _jobid;
        contractowner = msg.sender;
        productid = 0;
    }

    function addProducts(uint256 _price, uint256 _multiplier, uint256 _tokenT) public onlyOwner {
        products[productid]  = ProductInfo(productid,_price,_multiplier,TokenType(_tokenT));
        productid = productid + 1;
    }
   
    // Insurance Functions //
    function buyPolicy(string memory _policyHash, uint256 _productId, string memory _latlong, address _tokenAddr, uint256 _tokenT, uint256 _period) 
    public payable
    {
        require(msg.value >= 0.001*10**18, "Less than minimum 0.01 XDC");
        require(msg.value >= products[_productId].price, "Insufficient tx value for policy purchase");
        
        uint256 payableAmount = msg.value * products[_productId].payoutMultiplier;
        liquidityPool += uint256(msg.value);      
        uint256 _unlock = calculateDuration(_period);
        PolicyDetails memory pd = PolicyDetails(msg.sender, _policyHash, _productId, payableAmount,_latlong,  false, _tokenAddr, _tokenT,_unlock,Status(0));
        policies[msg.sender][_policyHash] = pd;
        policyIndex[msg.sender].push(_policyHash);

        //LOG event
        emit buyPolicyEvent(_policyHash, _productId, _latlong);
    }
    
    function viewPolicy(string memory _policyAddress) 
    public view returns (PolicyDetails memory)
    {
        PolicyDetails memory pd = policies[msg.sender][_policyAddress];
        return pd;
    }

   function submitMyClaim(string memory _policyHash) 
    public {
        PolicyDetails memory ipl = policies[msg.sender][_policyHash];
        require(ipl.policyHolder != address(0),"Policy Holder Address is invalid");
        require(ipl.paid != true,"Already claimed");
        require(ipl.payableAmount <= address(this).balance, "Not enough balance to pay!");
        Plugin.Request memory req = buildPluginRequest(stringToBytes32(_jobId), address(this), this.fulfillClaimInquiry.selector);
        // _unlockDate = block.timestamp + 50 seconds;
        req.addUint("until", ipl.unlockOn);
        bytes32 reqId = sendPluginRequestTo(_oracleContractAddr, req, ORACLE_PAYMENT);
        claims[reqId] = ipl;
        claimRequest[msg.sender]=reqId;

        emit submitMyClaimLog(_policyHash);
    }

    function fulfillClaimInquiry(bytes32 _requestId) public recordPluginFulfillment(_requestId)
    {
        PolicyDetails memory pol = claims[_requestId];
        policies[pol.policyHolder][pol.policyHash].paid = true;
        policies[pol.policyHolder][pol.policyHash].policystatus = Status(1);
        require(pol.payableAmount <= address(this).balance, "Not enough liquidity!");

        if(TokenType(pol.tokenType)==TokenType.NATIVE){
            pol.policyHolder.transfer(pol.payableAmount);
        }else{
            checkXRC20Balance(pol.payableAmount,pol.tokenAddress);
            transferToken(pol.payableAmount,pol.tokenAddress,pol.policyHolder);
        }
        emit claimPolicySuccessful(pol.policyHash);
    }

    function transferToken(uint256 _payablevalue,address _tokenaddr,address _beneficiary) internal{
        IXRC20(_tokenaddr).transferFrom(
            address(this),
            _beneficiary,
            _payablevalue
        );
    }

    function checkXRC20Balance(
        uint256 _AmountToCheckAgainst,
        address _currency
    ) internal view {
        require(IXRC20(_currency).balanceOf(address(this)) >=_AmountToCheckAgainst,"Not enough token to transfer");
    }
    
    //ACCOUNTING: Owner Balance & Withdrawal Functions
    //////////////////////////////////////////////////

    function addToBalance() 
    public payable 
    {}
    
    function getBalance() 
    public onlyOwner view returns(uint256) {
        return address(this).balance;
    }

    function withdrawAll() 
    public onlyOwner {
        address payable to = payable(contractowner);
        to.transfer(getBalance());
    }

    function withdrawAmount(uint256 amount) 
    public onlyOwner {
        address payable to = payable(msg.sender);
        to.transfer(amount);
    }

    function withdrawPli() 
    public onlyOwner {
    PliTokenInterface pli = PliTokenInterface(pluginTokenAddress());
        require(pli.transfer(msg.sender, pli.balanceOf(address(this))), "Unable to transfer");
    }
    
    //Utility functions
    function stringToBytes32(string memory source) 
    private pure returns (bytes32 result) 
    {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
        assembly {
            result := mload(add(source, 32))
        }
    
    }

    function calculateDuration(uint256 _period) internal returns(uint256){
        if (InsurancePeriod.TESTNOW == InsurancePeriod(_period)) {
            _unlockDate = block.timestamp + 50 seconds;
        }
        if (InsurancePeriod.MONTH3 == InsurancePeriod(_period)) {
            _unlockDate = block.timestamp + 90 days;
        }
        if (InsurancePeriod.MONTH6 == InsurancePeriod(_period)) {
            _unlockDate = block.timestamp + 180 days;
        }
        if (InsurancePeriod.MONTH9 == InsurancePeriod(_period)) {
            _unlockDate = block.timestamp + 270 days;
        }
        if (InsurancePeriod.MONTH12 == InsurancePeriod(_period)) {
            _unlockDate = block.timestamp + 360 days;
        }
        return _unlockDate;
    }

}