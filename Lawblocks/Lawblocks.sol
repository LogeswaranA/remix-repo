pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;
import "./Initializable.sol";
import "./IXRC20.sol";
import "./LawBlocksToken.sol";

contract LawBlocksMarket is Operator {
    //lawblocksToken
    LawBlocksToken lawblocksToken;

    //lawblocksToken
    address public owner;

    //TransactionFee Fee Percentage
    uint256 public transactionFee;
    uint256 public sharingFee;
    uint256 public signingFee;

    //Counters to track
    //_contractIds
    //_legalContractIds
    uint256 public _contractIds;

    //StoreContract Struct to track all contracts
    struct StoreContract {
        uint256 contractId;
        string contractName;
        string contractHash;
        address[] stakeHolders;
        address[] toSign;
        string[] signature;
        address uploadedBy;
        uint256 uploadedON;
    }

    mapping(uint256 => StoreContract) private storeContractId;


    mapping(uint256 => mapping(string => bool)) private contractToHash;

    //event to emit
    event contractStored(
        uint256 indexed contractId,
        string  contractHash,
        address uploadedBy
    );
    //event to emit
    event contractShared(
        uint256 indexed contractId,
        string  contractHash,
        address sharedBy,
        address sharedTo
    );

    event contractSigned(
        uint256 indexed contractId,
        string  contractHash,
        address signedBy
    );

    function initialize(LawBlocksToken _lawblocks) public initializer {
        lawblocksToken = _lawblocks;
        _contractIds = 1;
        owner = msg.sender;
        transactionFee = 0 ether;
        sharingFee = 0 ether;
        signingFee = 0 ether;
        _initializeOwner();
        _initializeOperator();
    }

    function transferContractOwnership(address _newOwneraddress)
        public
        onlyOwner
    {
        _transferOwner(_newOwneraddress);
    }

    function _transferOwner(address _newOwneraddress) internal {
        require(_newOwneraddress != address(0));
        emit OwnershipTransferred(owner, _newOwneraddress);
        owner = _newOwneraddress;
    }

    //Change Transaction or Uploading Fee
    function setTransactionFee(uint256 _fee) public {
        require(msg.sender == owner, "Only owners allowed to make this change");
        transactionFee = _fee;
    }

    //Change Sharing Fee
    function setSharingFee(uint256 _fee) public {
        require(msg.sender == owner, "Only owners allowed to make this change");
        sharingFee = _fee;
    }

    //Change Signing Fee
    function setSigningFee(uint256 _fee) public {
        require(msg.sender == owner, "Only owners allowed to make this change");
        signingFee = _fee;
    }

    //Function to upload Contract & store the hash of it
    function uploadFile(
        string memory _hashFile,
        string memory _contractName,
        string memory _signature
    ) public returns (bool) {
        uint256 _contractid = _contractIds;

        if (transactionFee > 0 ether) {
            checkXRC20BalAndAllowance(
                msg.sender,
                lawblocksToken,
                transactionFee
            );
            transferPayment(transactionFee, lawblocksToken);
            _contractIds++;
            storeContractId[_contractid].contractId = _contractid;
            storeContractId[_contractid].contractName = _contractName;
            storeContractId[_contractid].contractHash = _hashFile;
            storeContractId[_contractid].stakeHolders.push(msg.sender);
            storeContractId[_contractid].toSign.push(msg.sender);
            storeContractId[_contractid].signature.push(_signature);
            storeContractId[_contractid].uploadedBy = msg.sender;
            storeContractId[_contractid].uploadedON = block.timestamp;
            contractToHash[_contractid][_hashFile] = true;
            emit contractStored(_contractid, _hashFile, msg.sender);
        } else {
            _contractIds++;
            storeContractId[_contractid].contractId = _contractid;
            storeContractId[_contractid].contractName = _contractName;
            storeContractId[_contractid].contractHash = _hashFile;
            storeContractId[_contractid].stakeHolders.push(msg.sender);
            storeContractId[_contractid].toSign.push(msg.sender);
            storeContractId[_contractid].signature.push(_signature);
            storeContractId[_contractid].uploadedBy = msg.sender;
            storeContractId[_contractid].uploadedON = block.timestamp;
            contractToHash[_contractid][_hashFile] = true;
            emit contractStored(_contractid, _hashFile, msg.sender);
        }

        return true;
    }

    //Function to share file & store the hash of it
    function shareFile(
        uint256 _cid,
        string memory _hashFile,
        address sharedTo
    ) public returns (bool) {
        require(
            contractToHash[_cid][_hashFile] == true,
            "Hash file does not exists for this contract Id"
        );
        if (sharingFee > 0 ether) {
            checkXRC20BalAndAllowance(msg.sender, lawblocksToken, sharingFee);
            transferPayment(sharingFee, lawblocksToken);
            storeContractId[_cid].stakeHolders.push(sharedTo);
            storeContractId[_cid].toSign.push(sharedTo);
            emit contractShared(_cid, _hashFile, msg.sender, sharedTo);
            return true;
        } else {
            storeContractId[_cid].stakeHolders.push(sharedTo);
            storeContractId[_cid].toSign.push(sharedTo);
            emit contractShared(_cid, _hashFile, msg.sender, sharedTo);
            return true;
        }
    }

    //Function to upload Contract & store the hash of it
    function signContract(
        uint256 _cid,
        string memory _hashFile,
        string memory _signature
    ) public returns (bool) {
        require(
            contractToHash[_cid][_hashFile] == true,
            "Hash file does not exists for this contract Id"
        );
        if (signingFee > 0 ether) {
            checkXRC20BalAndAllowance(msg.sender, lawblocksToken, signingFee);
            transferPayment(signingFee, lawblocksToken);
            storeContractId[_cid].signature.push(_signature);
            emit contractSigned(_cid, _hashFile, msg.sender);
            return true;
        } else {
            storeContractId[_cid].signature.push(_signature);
            emit contractSigned(_cid, _hashFile, msg.sender);
            return true;
        }
    }

    function getAllContracts() public view returns (StoreContract[] memory) {
        uint256 itemCount = _contractIds - 1;
        uint256 currentIndex = 0;
        StoreContract[] memory items = new StoreContract[](itemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            uint256 currentId = i + 1;
            StoreContract storage currentItem = storeContractId[currentId];
            items[currentIndex] = currentItem;
            currentIndex += 1;
        }
        return items;
    }

    /* Returns all unsold market items */
    function fetchContractById(uint256 _itemId)
        public
        view
        returns (
            uint256 contractId,
            string memory contractName,
            string memory contractHash,
            address[] memory stakeHolders,
            address[] memory toSign,
            string[] memory signature,
            address uploadedBy,
            uint256 uploadedON
        )
    {
        StoreContract storage currentItem = storeContractId[_itemId];
        return (
            currentItem.contractId,
            currentItem.contractName,
            currentItem.contractHash,
            currentItem.stakeHolders,
            currentItem.toSign,
            currentItem.signature,
            currentItem.uploadedBy,
            currentItem.uploadedON
        );
    }

    function checkXRC20BalAndAllowance(
        address _addrToCheck,
        address _currency,
        uint256 _AmountToCheckAgainst
    ) internal view {
        require(
            IXRC20(_currency).balanceOf(_addrToCheck) >=
                _AmountToCheckAgainst &&
                IXRC20(_currency).allowance(_addrToCheck, address(this)) >=
                _AmountToCheckAgainst,
            "Lawblocks Market: insufficient currency balance or allowance."
        );
    }

    function transferPayment(uint256 _totalPrice, address _currency) internal {
        IXRC20(_currency).transferFrom(msg.sender, address(this), _totalPrice);
    }

    function withdrawBalance() public returns (bool) {
        require(owner == msg.sender, "Only Admin can call this function");
        uint256 _contractBalance = IXRC20(lawblocksToken).balanceOf(
            address(this)
        );
        require(_contractBalance > 0, "Contract Balance for this token is 0");

        IXRC20(lawblocksToken).transfer(msg.sender, _contractBalance);

        return true;
    }
}
