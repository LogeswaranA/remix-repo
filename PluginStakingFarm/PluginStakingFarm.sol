pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;
import "./Plugin.sol";

contract PluginStakingFarm is Operator {
    using SafeMath for uint256;

    //Plugin token instance
    Plugin pluginToken; 

    //To store the name and owner of the contract
    string public name;
    address public owner;

    //Staking cap for PLI Farm min and max
    uint256 private minstakingcapforPLIFarm;
    uint256 private maxstakingcapforPLIFarm;
    uint256 private overallPLIstakedforPLIFarm;

    //To check if PLI is locked for PLI Farm
    mapping(address => bool) private isPLILockedforPLIFarm;
    //To check if a PLI farm node is whitelisted
    mapping(address => bool) private whitelistPLIFarmNodes;
    //To store and retrieve the PLI staked by the user on PLI Farm
    mapping(address => uint256) private pliStakedForFarm;
    //To check list of PLI Farm Nodes setup by one wallet or user
    address[] private plifarmnodes;

    //Events to capture PLI Farm whitelist event
    event whiteListPLIFarmEvent(
        address owner,
        address staker,
        bool status
    );

    //Apothem PLI address - 0xb3db178db835b4dfcb4149b2161644058393267d
    //Mainnet PLI address - 0xff7412ea7c8445c46a8254dfb557ac1e48094391

    //Initialize function to run by proxy admin(one-time)
    function initialize(Plugin _pluginToken) public initializer {
        name = "Plugin Staking Farm";
        pluginToken = _pluginToken;
        owner = msg.sender;
        minstakingcapforPLIFarm = 50000 ether;   //PLIFARM -  50000
        maxstakingcapforPLIFarm = 1000000 ether; //PLIFARM - 1000000
        _initializeOwner();
        _initializeOperator();
    }

    //Update Staking Cap for PLI on PLI farm run by Contract owner
    function updateMinStakingCapForPLIForPLIFarm(uint256 _newMinStakingCap) public {
        require(msg.sender == owner, "Only Owner can do update");
        minstakingcapforPLIFarm = _newMinStakingCap;
    }

    //Update Staking Cap for PLI on PLI farm run by Contract owner
    function updateMaxStakingCapForPLIForPLIFarm(uint256 _newMaxStakingCap) public {
        require(msg.sender == owner, "Only Owner can do update");
        maxstakingcapforPLIFarm = _newMaxStakingCap;
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

    //Function to whitelist address of PLI Farm nodes
    function whiteListPLIFarmNode(address _to)
        public
        returns (uint256)
    {
        // Only owner can call this function
        require(msg.sender == owner, "caller must be the owner");
        require(
            whitelistPLIFarmNodes[_to] == false,
            "Already whitelisted for this pair"
        );
        whitelistPLIFarmNodes[_to] = true;
        plifarmnodes.push(_to);
        emit whiteListPLIFarmEvent(msg.sender, _to, true);
        return 0;
    }

    //Function to stake PLI for Farm
    //PLI Farm node must be whitelisted before
    //Staking amount should not exceed the capped limit of PLI
    function stakePLIforPLIFarm(uint256 _amount) public {
        //Get the PLI total stake for specific weather node address
        require(whitelistPLIFarmNodes[msg.sender]==true,"Should be whitelisted before"); //PLIFARM - Remove this check
        uint256 _totalStake = pliStakedForFarm[msg.sender].add(
            _amount
        );
        require(
            _totalStake <= maxstakingcapforPLIFarm,
            "You cannot exceed the allowed staking limit for PLI"
        );
        //Transfer PLI token from msg.sender to this contract
        pluginToken.transferFrom(msg.sender, address(this), _amount);
        //add the overallPLI staked
        overallPLIstakedforPLIFarm = overallPLIstakedforPLIFarm.add(_amount);
        //Update PLI staking balance for this user
        pliStakedForFarm[msg.sender] = _totalStake;
        //Lock the staked PLI flag
        isPLILockedforPLIFarm[msg.sender] = true;
    }

    //Function to return the total  PLI value staked by the user for corresponding PLIFarm node
    function PLIStakedBalanceOnPLIFarm(address _to)
        public
        view
        returns (uint256)
    {
        uint256 _plibal = pliStakedForFarm[_to];
        return _plibal;
    }

    // Function to Unstake PLI Tokens on PLIFarm
    // User PLI Farm Node must be unlocked by Admin
    // PLI to be transferred to user & balance will be set to zero
    function unstakeTokensOnPLIFarm() public {
        //check if user is unlocked
        require(
            isPLILockedforPLIFarm[msg.sender]== false,
            "User node account must be unlocked by ADMIN to unstake"
        );
        // Fetch staking balance
        uint256 balance = pliStakedForFarm[msg.sender];
        uint256 _newBalance = pliStakedForFarm[msg.sender].sub(
            balance
        );

        // Require amount greater than 0
        require(balance > 0, "Already unstaked, balance is 0");
        // Release PLI tokens to this address
        pluginToken.transfer(msg.sender, balance);

        overallPLIstakedforPLIFarm = overallPLIstakedforPLIFarm.sub(balance);
        // Reset staking balance for that node
        pliStakedForFarm[msg.sender] = _newBalance;
        //remove the node from whitelisting
        whitelistPLIFarmNodes[msg.sender] = false;
    }

    // Unlock PLI to be done by Admin
    function unlockPLI(address _to)
        public
    {
        // Only owner can call this function
        require(msg.sender == owner, "caller must be the owner");
        // Unlock
        isPLILockedforPLIFarm[_to] = false;
    }

    // Blacklist the weather unit
    // To be called by Admin or owner
    function blackList(address _to)
        public
        returns (uint256)
    {
        // Only owner can call this function
        require(msg.sender == owner, "caller must be the owner");
        require(
            whitelistPLIFarmNodes[_to] == true,
            "Not whitelisted yet"
        );
        // Only owner can call this function
        whitelistPLIFarmNodes[_to] = false;
        emit whiteListPLIFarmEvent(msg.sender, _to, false);
        return 0;
    }

    //Function to check if unit is whitelisted or not
    function isUnitWhitelisted(address _to)
        public
        view
        returns (bool)
    {
        return whitelistPLIFarmNodes[_to];
    }

    //Function to return the if XDC / PLI value is locked or not
    function isPLILockedForFarm(address _to)
        public
        view
        returns (bool)
    {
        return (isPLILockedforPLIFarm[_to]);
    }

    //Function to return overall staked balance available in the contract
    function getPLIStakedBalanceOnPLIFarm() public view returns (uint256 _overallPLIStaked) {
        return (overallPLIstakedforPLIFarm);
    }

    //Function to return total PLI balance available in the contract
    function getPLIBalance() public view returns (uint256 _pliInContract) {
        return pluginToken.balanceOf(address(this));
    }

    //Function to get list of all PLI Farm address
    function getAllStakedPLIFarmNodes () public view returns (address[] _farmnodes){
        return plifarmnodes;
    }

    //Function to return getStakingCap 
    function getStakingCap() public view returns (uint256 _minpliCap,uint256 _maxpliCap) {
        return (minstakingcapforPLIFarm,maxstakingcapforPLIFarm);
    }
}