pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;
import "./Operator.sol";

contract WeatherFarmXDC is Operator {
    using SafeMath for uint256;

    string public name;
    address public owner;

    //staking cap for XDC
    uint256 public stakingcapforXDC;
    address[] public stakers;

    uint256 private OverallXDCStaked;

    mapping(address=>bool) private hasStaked;

    mapping(address => mapping(string => uint256)) private xdcStaked;
    
    mapping(address => mapping(string => mapping(uint256 => uint256)))
        private XDCRewardReceived;
    mapping(address => mapping(string => bool)) private isXDCLocked;

    //Whitelist address
    mapping(address => mapping(string => bool)) private whitelistNodes;
    mapping(address=>string[]) private weathernodes;

    //Events to capture whitelist event
    event whiteListEvent(
        address owner,
        address staker,
        string nodeadd,
        bool status
    );


    //Events to capture whitelist event
    event xdcStakedByUser(
        address staker,
        string nodeadd,
        uint256 stakedValue,
        bool status
    );

    //Events to capture whitelist event
    event xdcUnStakedByUser(
        address staker,
        string nodeadd,
        uint256 stakedValue,
        bool status
    );

        //Events to capture whitelist event
    event xdcUnlockedByAdmin(
        address staker,
        string nodeadd,
        bool status
    );

    function initialize() public initializer {
        name = "Plugin Weather Unit Staking Farm";
        owner = msg.sender;
        stakingcapforXDC = 5 ether;
        _initializeOwner();
        _initializeOperator();
    }

    function updateStakingCapForXDC(uint256 _newStakingCap) public {
        require(msg.sender == owner, "Only Owner can do update");
        stakingcapforXDC = _newStakingCap;
    }


    function transferContractOwnership(address _newOwneraddress)
        public onlyOwner()
    {
        _transferOwner(_newOwneraddress);
    }

    function _transferOwner(address _newOwneraddress) internal {
        require(_newOwneraddress != address(0));
        emit OwnershipTransferred(owner, _newOwneraddress);
        owner = _newOwneraddress;
    }

    //Function to whitelist address
    function whiteListIt(address _to, string memory _weatheraddress)
        public
        returns (uint256)
    {
        // Only owner can call this function
        require(msg.sender == owner, "caller must be the owner");
        require(
            whitelistNodes[_to][_weatheraddress] == false,
            "Already whitelisted for this pair"
        );
        whitelistNodes[_to][_weatheraddress] = true;
        weathernodes[_to].push(_weatheraddress);
        emit whiteListEvent(msg.sender, _to, _weatheraddress, true);
        return 0;
    }

    function stakeXdc(string memory _weatheraddress) public payable {
        require(whitelistNodes[msg.sender][_weatheraddress]==true,"Should be whitelisted before");
        //Get the total stake for specific weather node address
        uint256 _totalStake = xdcStaked[msg.sender][_weatheraddress].add(
            msg.value
        );
        require(
            _totalStake <= stakingcapforXDC,
            "You cannot exceed the allowed staking limit for XDC"
        );
        // require(msg.value == _remaningValue,"Should pass precise value to stake");
        //Transfer the XDC to beneficiary from msg.sender
        address(this).call.value(msg.value);

        //Overall XDC Staked 
        OverallXDCStaked = OverallXDCStaked.add(msg.value);
        //Add the XDC Staking balance
        xdcStaked[msg.sender][_weatheraddress] = _totalStake;

        //Set the XDC in locking status
        isXDCLocked[msg.sender][_weatheraddress] = true;

        //add staker into stakers list
        if(!hasStaked[msg.sender]){
            stakers.push(msg.sender);
            hasStaked[msg.sender]=true;
        }

        emit xdcStakedByUser(msg.sender,_weatheraddress,msg.value,true);
    }

    //Function to return the total XDC value staked by the user for corresponding weather node
    function XDCStakedBalance(address _to, string memory _weatheraddress)
        public
        view
        returns (uint256)
    {
        uint256 _xdcbal = xdcStaked[_to][_weatheraddress];
        return (_xdcbal);
    }

    // Unlock address
    function unlockXDCStake(address _to, string memory _weatheraddress)
        public
    {
        // Only owner can call this function
        require(msg.sender == owner, "caller must be the owner");
        // Unlock
        isXDCLocked[_to][_weatheraddress] = false;

        emit xdcUnlockedByAdmin(_to,_weatheraddress,true);
    }

    // Block the node and set whitelist to false
    function blockNode(address _to, string memory _weatheraddress)
        public
        returns (uint256)
    {
        // Only owner can call this function
        require(msg.sender == owner, "caller must be the owner");
        require(
            whitelistNodes[_to][_weatheraddress] == true,
            "Not whitelisted yet"
        );
        // Only owner can call this function
        whitelistNodes[_to][_weatheraddress] = false;
        emit whiteListEvent(msg.sender, _to, _weatheraddress, false);
        return 0;
    }

    //Function to return the total XDC value staked by the user for corresponding weather node
    function isUnitWhitelisted(address _to, string memory _weatheraddress)
        public
        view
        returns (bool)
    {
        return whitelistNodes[_to][_weatheraddress];
    }

        //Function to return the total XDC value staked by the user for corresponding weather node
    function hasXDCLocked(address _to, string memory _weatheraddress)
        public
        view
        returns (bool)
    {
        return (isXDCLocked[_to][_weatheraddress]);
    }

    function showNodes(address _to) public view returns (string[]){
        return weathernodes[_to];
    }

    function getStakedBalance() public view returns (uint256 _overallXDCStaked) {
        return (OverallXDCStaked);
    }

    function getActualXDCBalanceInContract() public view returns (uint256 _xdcInContract) {
       return address(this).balance;
    }

}
