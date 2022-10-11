pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;
import "./Plugin.sol";
import "./WeatherFarmFinal.sol";

contract WeatherRewardsMgmt is Operator {
    using SafeMath for uint256;

    //Plugin token instance
    Plugin pluginToken;

    //WeatherStakingFarm instance
    WeatherStakingFarm weatherfarm;

    //To store the name and owner of the contract
    string public name;
    address public owner;

    mapping(address => mapping(string => mapping(uint256 => uint256)))
        private PLIRewardReceived;
    
    mapping(address => mapping(string => mapping(uint256 => uint256)))
        private XDCRewardReceived;

    //Apothem PLI address - 0xb3db178db835b4dfcb4149b2161644058393267d
    //Mainnet PLI address - 0xff7412ea7c8445c46a8254dfb557ac1e48094391
    //Apothem WeatherFarm Address - 0xebA5880252f5Cad875099d87809d99a916891c7F
    //Mainnet WeatherFarm Address - 0x06892B4c9f612312E0981f0CA95CF06890708F74

    function initialize(Plugin _pluginToken,WeatherStakingFarm _weatherfarm) public initializer {
        name = "Plugin Weather Unit Rewards Farm";
        pluginToken = _pluginToken;
        weatherfarm = _weatherfarm;
        owner = msg.sender;
        _initializeOwner();
        _initializeOperator();
    }

    //function to accept XDC by Contract
    function addXdc() public payable {
    }

    //function to accept PLI by Contract
    function depositPLI(uint256 _amount) public {
        require(msg.sender == owner, "Only Owner can do call this function");
        require(_amount > 0, "Deposit Amount must be greater than 0");
        //Transfer PLI token from msg.sender to this contract
        pluginToken.transferFrom(msg.sender, address(this), _amount);
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

    //Send PLI token reward to beneficiary - 
    //Bulk Transfer it can handle 255 Txn at a time
    function bulksendPLIReward(
        address[] memory _to,
        uint256[] memory _values,
        uint256[] memory _dateno,
        string[] memory _nodes
    ) public returns(bool){
        require(msg.sender == owner, "caller must be the owner");
        require(_to.length == _values.length);
        require(_to.length <= 255);
        uint256 _totalAmount = pluginToken.balanceOf(address(this));
        for (uint256 i = 0; i < _to.length; i++) {
            if(_totalAmount>=_values[i]){
                if (weatherfarm.isUnitWhitelisted(_to[i],_nodes[i]) == true) {
                    pluginToken.transfer(_to[i], _values[i]);
                    PLIRewardReceived[_to[i]][_nodes[i]][_dateno[i]] = _values[i];
                    _totalAmount = _totalAmount.sub(_values[i]);
                }
            }else {
                return false;
            }
        }
        return true;
    }

    //Send XDC token reward to beneficiary - 
    //Bulk Transfer it can handle 255 Txn at a time
    function bulksendXDCReward(
        address[] memory _to,
        uint256[] memory _values,
        uint256[] memory _dateno,
        string[] memory _nodes
    ) public returns(bool) {
        require(msg.sender == owner, "caller must be the owner");
        require(_to.length == _values.length);
        require(_to.length <= 255);
        uint256 _totalAmount = address(this).balance;
        for (uint256 i = 0; i < _to.length; i++) {
            if(_totalAmount >=_values[i]){
                if (weatherfarm.isUnitWhitelisted(_to[i],_nodes[i]) == true) {
                    _to[i].transfer(_values[i]);
                    XDCRewardReceived[_to[i]][_nodes[i]][_dateno[i]] = _values[i];
                    _totalAmount = _totalAmount.sub(_values[i]);
                }
            }else {
                return false;
            }
        }
        return true;
    }

    //Send PLI token reward to beneficiary
    function sendPLIReward(
        address _to,
        uint256 _values,
        uint256 _dateno,
        string memory _nodes
    ) public {
        require(msg.sender == owner, "caller must be the owner");
        require(
            weatherfarm.isUnitWhitelisted(_to,_nodes) == true,
            "Should be whitelisted to receive rewards"
        );
        require(_values > 0, "Reward must be greater than 0");
        pluginToken.transfer(_to, _values);
        PLIRewardReceived[_to][_nodes][_dateno] = _values;
    }

    //Send XDC token reward to beneficiary
    function sendXDCReward(
        address _to,
        uint256 _values,
        uint256 _dateno,
        string memory _nodes
    ) public  {
        require(msg.sender == owner, "caller must be the owner");
        require(
            weatherfarm.isUnitWhitelisted(_to,_nodes) == true,
            "Should be whitelisted to receive rewards"
        );
        require(_values > 0, "Reward must be greater than 0");
        require(
             address(this).balance >= _values,
            "No sufficient balance to payout for XDC"
        );
        _to.transfer(_values);
        XDCRewardReceived[_to][_nodes][_dateno] = _values;
    }

    //Function to return total XDC balance available in the contract
    function getXDCBalance() public view returns (uint256 _xdcInContract) {
        return address(this).balance;
    }

    //Function to return total PLI balance available in the contract
    function getPLIBalance() public view returns (uint256 _pliInContract) {
        return pluginToken.balanceOf(address(this));
    }

}
