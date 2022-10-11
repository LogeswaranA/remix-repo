pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;
import "./Plugin.sol";

contract WeatherStakingFarm is Operator {
    using SafeMath for uint256;

    //Plugin token instance
    Plugin pluginToken;

    //To store the name and owner of the contract
    string public name;
    address public owner;

    //stakers list
    address[] public stakers;

    //staking cap for both XDC & PLI
    uint256 private stakingcapforXDC;
    uint256 private stakingcapforPLI;

    //Overall Stake amount of PLI & XDC
    uint256 private OverallXDCStaked;
    uint256 private OverallPLIStaked;

    //To check if staker hasStaked already
    mapping(address=>bool) private hasStaked;
    //To store and retrieve the XDC staked by the user
    mapping(address => mapping(string => uint256)) private xdcStaked;
    //To store and retrieve the PLI staked by the user
    mapping(address => mapping(string => uint256)) private pliStaked;
    //To check if XDC is locked
    mapping(address => mapping(string => bool)) private isXDCLocked;
    //To check if PLI is locked
    mapping(address => mapping(string => bool)) private isPLILocked;
    //To check list of whitelisted weather units
    mapping(address => mapping(string => bool)) private whitelistNodes;
    //To check list of weather units setup by one wallet or user
    mapping(address=>string[]) private weathernodes;

    //Events to capture whitelist event
    event whiteListEvent(
        address owner,
        address staker,
        string nodeadd,
        bool status
    );

    //Events to capture staked event
    event xdcStakedByUser(
        address staker,
        string nodeadd,
        uint256 stakedValue,
        bool status
    );

    //Events to capture unstakedby user event
    event xdcUnStakedByUser(
        address staker,
        string nodeadd,
        uint256 stakedValue,
        bool status
    );

    //Events to capture unlockbyadmin event
    event xdcUnlockedByAdmin(
        address staker,
        string nodeadd,
        bool status
    );

    //Apothem PLI address - 0xb3db178db835b4dfcb4149b2161644058393267d
    //Mainnet PLI address - 0xff7412ea7c8445c46a8254dfb557ac1e48094391

    //Initialize function to run by proxy admin(one-time)
    function initialize(Plugin _pluginToken) public initializer {
        name = "Plugin Weather Unit Staking Farm";
        pluginToken = _pluginToken;
        owner = msg.sender;
        stakingcapforXDC = 5 ether;
        stakingcapforPLI = 5 ether;
        _initializeOwner();
        _initializeOperator();
    }

    //Update Staking Cap for XDC to run by Contract owner
    function updateStakingCapForXDC(uint256 _newStakingCap) public {
        require(msg.sender == owner, "Only Owner can do update");
        stakingcapforXDC = _newStakingCap;
    }

    //Update Staking Cap for PLI to run by Contract owner
    function updateStakingCapForPLI(uint256 _newStakingCap) public {
        require(msg.sender == owner, "Only Owner can do update");
        stakingcapforPLI = _newStakingCap;
    }

    //function to accept XDC by Contract
    function addXdc() public payable {
    }

    //To Transfer the ownership of contract 
    function transferContractOwnership(address _newOwneraddress)
        public onlyOwner()
    {
        _transferOwner(_newOwneraddress);
    }

    //To Transfer the ownership of contract (Internal function)
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

    //Function to stake XDC
    //Weather Unit must be whitelisted before
    //Staking amount should not exceed the capped limit of XDC
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
    }

    //Function to stake PLI
    //Weather Unit must be whitelisted before
    //Staking amount should not exceed the capped limit of PLI
    function stakePLI(string memory _weatheraddress, uint256 _amount) public {
        //Get the PLI total stake for specific weather node address
        require(whitelistNodes[msg.sender][_weatheraddress]==true,"Should be whitelisted before");
        uint256 _totalStake = pliStaked[msg.sender][_weatheraddress].add(
            _amount
        );
        require(
            _totalStake <= stakingcapforPLI,
            "You cannot exceed the allowed staking limit for PLI"
        );
        //Transfer PLI token from msg.sender to this contract
        pluginToken.transferFrom(msg.sender, address(this), _amount);
        //add the overallPLI staked
        OverallPLIStaked = OverallPLIStaked.add(_amount);
        //Update PLI staking balance for this user
        pliStaked[msg.sender][_weatheraddress] = _totalStake;
        //Lock the staked PLI flag
        isPLILocked[msg.sender][_weatheraddress] = true;
    }

    //Function to return the total XDC & PLI value staked by the user for corresponding weather node
    function XDCPLIStakedBalance(address _to, string memory _weatheraddress)
        public
        view
        returns (uint256, uint256)
    {
        uint256 _xdcbal = xdcStaked[_to][_weatheraddress];
        uint256 _plibal = pliStaked[_to][_weatheraddress];
        return (_xdcbal, _plibal);
    }

    // Function to Unstake XDC Tokens 
    // User weather unit must be unlocked by Admin
    // XDC to be transferred to user & balance will be set to zero
    function unstakeXDC(string _weatheraddress) public{
        require(
            isXDCLocked[msg.sender][_weatheraddress] == false,
            "User weather node account must be unlocked by ADMIN to unstake XDC"
        );
        // Fetch staking balance
        uint256 balance = xdcStaked[msg.sender][_weatheraddress];
        uint256 _newBalance = xdcStaked[msg.sender][_weatheraddress].sub(balance);
        // Require amount greater than 0
        require(balance > 0, "Already unstaked, balance is 0");
        // Release XDC tokens to this address
        msg.sender.transfer(balance);
        //updat overallbalance
        OverallXDCStaked = OverallXDCStaked.sub(balance);
        // Reset staking balance for that node
        xdcStaked[msg.sender][_weatheraddress] = _newBalance;
        //remove the node from whitelisting
        whitelistNodes[msg.sender][_weatheraddress] = false;
    }

    // Function to Unstake PLI Tokens 
    // User weather unit must be unlocked by Admin
    // PLI to be transferred to user & balance will be set to zero
    function unstakeTokens(string memory _weatheraddress) public {
        //check if user is unlocked
        require(
            isPLILocked[msg.sender][_weatheraddress] == false,
            "User node account must be unlocked by ADMIN to unstake"
        );
        // Fetch staking balance

        uint256 balance = pliStaked[msg.sender][_weatheraddress];
        uint256 _newBalance = pliStaked[msg.sender][_weatheraddress].sub(
            balance
        );

        // Require amount greater than 0
        require(balance > 0, "Already unstaked, balance is 0");
        // Release PLI tokens to this address
        pluginToken.transfer(msg.sender, balance);

        OverallPLIStaked = OverallPLIStaked.sub(balance);
        // Reset staking balance for that node
        pliStaked[msg.sender][_weatheraddress] = _newBalance;
        //remove the node from whitelisting
        whitelistNodes[msg.sender][_weatheraddress] = false;
    }

    // Unlock XDC & PLI to be done by Admin
    function unlockXDCPLI(address _to, string memory _weatheraddress)
        public
    {
        // Only owner can call this function
        require(msg.sender == owner, "caller must be the owner");
        // Unlock
        isXDCLocked[_to][_weatheraddress] = false;
        isPLILocked[_to][_weatheraddress] = false;
    }

    // Blacklist the weather unit
    // To be called by Admin or owner
    function blackList(address _to, string memory _weatheraddress)
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

    //Function to check if unit is whitelisted or not
    function isUnitWhitelisted(address _to, string memory _weatheraddress)
        public
        view
        returns (bool)
    {
        return whitelistNodes[_to][_weatheraddress];
    }

    //Function to return the if XDC / PLI value is locked or not
    function isXDCPLILocked(address _to, string memory _weatheraddress)
        public
        view
        returns (bool,bool)
    {
        return (isXDCLocked[_to][_weatheraddress],isPLILocked[_to][_weatheraddress]);
    }

    //Function to return list of weather units setup by the user
    function showNodes(address _to) public view returns (string[]){
        return weathernodes[_to];
    }

    //Function to return overall staked balance available in the contract
    function getStakedBalance() public view returns (uint256 _overallPLIStaked,uint256 _overallXDCStaked) {
        return (OverallPLIStaked,OverallXDCStaked);
    }

    //Function to return total XDC balance available in the contract
    function getXDCBalance() public view returns (uint256 _xdcInContract) {
        return address(this).balance;
    }

    //Function to return total PLI balance available in the contract
    function getPLIBalance() public view returns (uint256 _pliInContract) {
        return pluginToken.balanceOf(address(this));
    }

    //Function to return staker list
    function getStakersList() public view returns (address[] _stakers) {
        return stakers;
    }

    //Function to return getStakingCap 
    function getStakingCap() public view returns (uint256 _xdcCap,uint256 _pliCap) {
        return (stakingcapforXDC,stakingcapforPLI);
    }

}
