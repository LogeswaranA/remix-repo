pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;
import "./Plugin.sol";
import "./PluginStakingFarm.sol";

contract PLIFarmRewardsMgmt is Operator {
    using SafeMath for uint256;

    //Plugin token instance
    Plugin pluginToken;

    //PluginStakingFarm instance
    PluginStakingFarm plifarm;

    //To store the name and owner of the contract
    string public name;
    address public owner;

    mapping(address =>  mapping(uint256 => uint256))
        private PLIRewardReceived;

    function initialize(Plugin _pluginToken,PluginStakingFarm _plifarm) public initializer {
        name = "Plugin PLIFarm Rewards Farm";
        pluginToken = _pluginToken;
        plifarm = _plifarm;
        owner = msg.sender;
        _initializeOwner();
        _initializeOperator();
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
        uint256[] memory _dateno
    ) public returns(bool){
        require(msg.sender == owner, "caller must be the owner");
        require(_to.length == _values.length);
        require(_to.length <= 255);
        uint256 _totalAmount = pluginToken.balanceOf(address(this));
        for (uint256 i = 0; i < _to.length; i++) {
            if(_totalAmount>=_values[i]){
                if (plifarm.isUnitWhitelisted(_to[i]) == true) {
                    pluginToken.transfer(_to[i], _values[i]);
                    PLIRewardReceived[_to[i]][_dateno[i]] = _values[i];
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
        uint256 _dateno
    ) public {
        require(msg.sender == owner, "caller must be the owner");
        require(
            plifarm.isUnitWhitelisted(_to) == true,
            "Should be whitelisted to receive rewards"
        );
        require(_values > 0, "Reward must be greater than 0");
        pluginToken.transfer(_to, _values);
        PLIRewardReceived[_to][_dateno] = _values;
    }
    
    //Function to return total PLI balance available in the contract
    function getPLIBalance() public view returns (uint256 _pliInContract) {
        return pluginToken.balanceOf(address(this));
    }

}