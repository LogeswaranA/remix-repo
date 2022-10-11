pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;
import "./PluginPLIG.sol";

contract WeatherStakingFarm is Operator {
    using SafeMath for uint256;

    string public name;
    address public owner;

    //staking cap for both XDC & PLI
    uint256 public stakingcapforXDC;
    uint256 public stakingcapforPLI;

    uint256 private OverallXDCStaked;
    uint256 private OverallPLIStaked;

    Plugin pluginToken;

    //Beneficiarty 
    address[] public stakers;
    mapping(address => mapping(string => uint256)) private xdcStaked;
    mapping(address => mapping(string => uint256)) private pliStaked;

    mapping(address => mapping(string => mapping(uint256 => uint256)))
        private PLIRewardReceived;
    
    mapping(address => mapping(string => mapping(uint256 => uint256)))
        private XDCRewardReceived;
    mapping(address => mapping(string => bool)) private isXDCLocked;
    mapping(address => mapping(string => bool)) private isPLILocked;

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

    //Apothem PLI address - 0xb3db178db835b4dfcb4149b2161644058393267d
    //Mainnet PLI address - 0xff7412ea7c8445c46a8254dfb557ac1e48094391

    function initialize(Plugin _pluginToken) public initializer {
        name = "Plugin Weather Unit Staking Farm";
        pluginToken = _pluginToken;
        owner = msg.sender;
        stakingcapforXDC = 5 ether;
        stakingcapforPLI = 5 ether;
        _initializeOwner();
        _initializeOperator();
    }

    function updateStakingCapForXDC(uint256 _newStakingCap) public {
        require(msg.sender == owner, "Only Owner can do update");
        stakingcapforXDC = _newStakingCap;
    }

    function updateStakingCapForPLI(uint256 _newStakingCap) public {
        require(msg.sender == owner, "Only Owner can do update");
        stakingcapforPLI = _newStakingCap;
    }


    //function to accept PLI
    function addXdc() public payable {
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
    }

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
        // require(_amount == _remaningValue,"Should pass precise value to stake");

        //Transfer PLI token from msg.sender to this contract
        pluginToken.transferFrom(msg.sender, address(this), _amount);

        //add the overallPLI staked
        OverallPLIStaked = OverallPLIStaked.add(_amount);
        //Update PLI staking balance for this user
        pliStaked[msg.sender][_weatheraddress] = _totalStake;
        //Lock the staked PLI flag
        isPLILocked[msg.sender][_weatheraddress] = true;
    }

    //Function to return the total XDC value staked by the user for corresponding weather node
    function XDCPLIStakedBalance(address _to, string memory _weatheraddress)
        public
        view
        returns (uint256, uint256)
    {
        uint256 _xdcbal = xdcStaked[_to][_weatheraddress];
        uint256 _plibal = pliStaked[_to][_weatheraddress];
        return (_xdcbal, _plibal);
    }

    // // Release XDC Tokens if user want to unstake by Admin
    function releaseXDC(address _to, string _weatheraddress) public payable{
        require(msg.sender == owner, "Only owner can call this function");
        require(
            isXDCLocked[_to][_weatheraddress] == false,
            "User weather node account must be unlocked by ADMIN to unstake XDC"
        );
        // Fetch staking balance
        uint256 balance = xdcStaked[_to][_weatheraddress];
        uint256 _newBalance = xdcStaked[_to][_weatheraddress].sub(balance);
        // Require amount greater than 0
        require(balance > 0, "Already unstaked, balance is 0");
        //check if user is unlocked

        // Release PLI tokens to this address
        _to.transfer(balance);
        //updat overallbalance
        OverallXDCStaked = OverallXDCStaked.sub(balance);
        // Reset staking balance for that node
        xdcStaked[_to][_weatheraddress] = _newBalance;
        //remove the node from whitelisting
        whitelistNodes[_to][_weatheraddress] = false;
    }

    // Unstaking PLI Tokens (Withdraw) by user
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
        // Reset staking balance for that node
        pliStaked[msg.sender][_weatheraddress] = _newBalance;

        //remove the node from whitelisting
        whitelistNodes[msg.sender][_weatheraddress] = false;
    }

    // //Send PLI token reward to beneficiary -Bulk
    function bulksendPLIReward(
        address[] memory _to,
        uint256[] memory _values,
        uint256[] memory _dateno,
        string[] memory _nodes
    ) public {
        require(msg.sender == owner, "caller must be the owner");
        require(_to.length == _values.length);
        require(_to.length <= 255);
        for (uint256 i = 0; i < _to.length; i++) {
            if (whitelistNodes[_to[i]][_nodes[i]] == true) {
                OverallPLIStaked = OverallPLIStaked.sub(_values[i]);
                pluginToken.transfer(_to[i], _values[i]);
                PLIRewardReceived[_to[i]][_nodes[i]][_dateno[i]] = _values[i];
            }
        }
    }

    // //Send PLI token reward to beneficiary -Bulk
    function bulksendXDCReward(
        address[] memory _to,
        uint256[] memory _values,
        uint256[] memory _dateno,
        string[] memory _nodes
    ) public payable {
        require(msg.sender == owner, "caller must be the owner");
        require(_to.length == _values.length);
        require(_to.length <= 255);
        for (uint256 i = 0; i < _to.length; i++) {
            if (whitelistNodes[_to[i]][_nodes[i]] == true) {
                _to[i].transfer(_values[i]);
                XDCRewardReceived[_to[i]][_nodes[i]][_dateno[i]] = _values[i];
            }
        }
    }

    // //Send PLI token reward to beneficiary
    function sendPLIReward(
        address _to,
        uint256 _values,
        uint256 _dateno,
        string memory _nodes
    ) public {
        require(msg.sender == owner, "caller must be the owner");
        require(
            whitelistNodes[_to][_nodes] == true,
            "Should be whitelisted to receive rewards"
        );
        require(_values > 0, "Reward must be greater than 0");
        OverallPLIStaked = OverallPLIStaked.sub(_values);
        pluginToken.transfer(_to, _values);
        PLIRewardReceived[_to][_nodes][_dateno] = _values;
    }

    // //Send XDC token reward to beneficiary
    function sendXDCReward(
        address _to,
        uint256 _values,
        uint256 _dateno,
        string memory _nodes
    ) public payable {
        require(msg.sender == owner, "caller must be the owner");
        require(
            whitelistNodes[_to][_nodes] == true,
            "Should be whitelisted to receive rewards"
        );
        require(_values > 0, "Reward must be greater than 0");
        require(
            msg.value >= _values,
            "No sufficient balance to payout for XDC"
        );
        _to.transfer(_values);
        XDCRewardReceived[_to][_nodes][_dateno] = _values;
    }

    // Unlock address
    function unlockXDCPLI(address _to, string memory _weatheraddress)
        public
    {
        // Only owner can call this function
        require(msg.sender == owner, "caller must be the owner");
        // Unlock
        isXDCLocked[_to][_weatheraddress] = false;
        isPLILocked[_to][_weatheraddress] = false;
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
    function isXDCPLILocked(address _to, string memory _weatheraddress)
        public
        view
        returns (bool,bool)
    {
        return (isXDCLocked[_to][_weatheraddress],isPLILocked[_to][_weatheraddress]);
    }

    function showNodes(address _to) public view returns (string[]){
        return weathernodes[_to];
    }

    function getStakedBalance() public view returns (uint256 _overallPLIStaked,uint256 _overallXDCStaked) {
        return (OverallPLIStaked,OverallXDCStaked);
    }

    function getXDCBalance() public view returns (uint256 _xdcInContract) {
        return address(this).balance;
    }

    function getPLIBalance() public view returns (uint256 _xdcInContract) {
        return pluginToken.balanceOf(address(this));
    }

}
