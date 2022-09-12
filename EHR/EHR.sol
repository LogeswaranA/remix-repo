//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// import "./interface/PatientInterface.sol";
// import "./interface/DoctorInterface.sol";
// import "./interface/FileInterface.sol";
// import "./utils/Counters.sol";
// import "@goplugin/contracts/src/v0.8/PluginClient.sol";

import "PatientInterface.sol";
import "DoctorInterface.sol";
import "FileInterface.sol";
import "Counters.sol";
import "@goplugin/contracts/src/v0.8/PluginClient.sol";

contract EHR is PluginClient, PatientInterface, DoctorInterface, FileInterface {
    using Counters for Counters.Counter;
    Counters.Counter private _doctorIds;
    Counters.Counter private _patientIds;
    Counters.Counter private _recordIds;
    Counters.Counter private _viewIds;

    using Plugin for Plugin.Request;

    uint256 private constant ORACLE_PAYMENT = 0.001 * 10**18;

    // address
    address public owner;
    mapping(uint256 => Record) public records;
    mapping(uint256 => Patient) public patients;
    mapping(uint256 => Doctor) public doctors;
    // mapping(address => mapping (address => bool)) private patientToDoctor;
    // mapping(address => mapping (bytes32 => bool)) private patientToFile;
    mapping(uint256 => mapping (uint256 => bool)) public patientToDoctor;
    mapping(uint256 => mapping (string => bool)) public patientToFile;
    //mapping(bytes32 => filesInfo) public hashToFile; //filehash to file
    mapping(string => filesInfo) public hashToFile; //filehash to file
    mapping(address => bool) public doctorsRegistered;
    mapping(uint256 => DocumentLogs) public documentLogs;
    mapping(bytes32 => DocumentLogs) public documentLogRequestIds;



    constructor(address _pli) {
        setPluginToken(_pli);
        owner = msg.sender;
        _doctorIds.increment();
        _patientIds.increment();
        _recordIds.increment();
        _viewIds.increment();
    }

    modifier only_owner() {
        require(owner == msg.sender);
        _;
    }

    // modifier checkDoctor(address doctor) {
    //     Doctor memory d = doctors[doctor];
    //     require(d.doctor > address(0x0));//check if doctor exist
    //     _;
    //   }
      
    //   modifier checkPatient(address patient) {
    //     Patient memory p = patients[patient];
    //     require(p.patient > address(0x0));//check if patient exist
    //     _;
    //   }
        modifier checkPatient(uint256 patientId) {
            Patient memory p = patients[patientId];
            require(p.patient > address(0x0));
            _;
        }

    event RecordEvents(
        uint256 recordId,
        string eventType,
        address patient,
        address performedBy,
        uint256 performedOn
    );

    event DoctorEvents(
        uint256 doctorId,
        string eventType,
        address doctor,
        address performedBy,
        uint256 performedOn
    );

    event PatientEvents(
        uint256 patientId,
        string eventType,
        address patient,
        address performedBy,
        uint256 performedOn
    );

    //Initialize event requestCreated
    event requestCreated(
        address indexed requester,
        bytes32 indexed jobId,
        bytes32 indexed requestId
    );

    //Initialize event RequestPermissionFulfilled
    event RequestPermissionFulfilled(
        bytes32 indexed requestId,
        uint256 indexed otp
    );

    event FileUpload(
        string _file_name,
        address patientId
    );

    event debugConsole(
        uint256 _patientId
    );
    // Register Patient
    function registerPatients(
        address _patientAddress,
        string memory _metaData,
        string memory _careGiverContact,
        string memory _careGiverName,
        Status _status,
        Sex _gender
    ) public returns (uint256) {
        uint256 _patientid = _patientIds.current();
        _patientIds.increment();

        uint256 unique_id = uint256(
            sha256(abi.encodePacked(msg.sender, block.timestamp))
        );

        patients[_patientid] = Patient(
            _patientid,
            unique_id,
            _patientAddress,
            _metaData,
            Sex(_gender),
            block.timestamp,
            msg.sender,
            _careGiverName,
            _careGiverContact,
            Status(_status)
            
        );
        emit PatientEvents(
            _patientid,
            "Patient Registered",
            msg.sender,
            msg.sender,
            block.timestamp
        );

        return unique_id;
    }

    // Register Doctor
    function registerDoctor(
        address _doctorAddress,
        string memory _metaData,
        DoctorType _doctorType,
        Status _status,
        Sex _gender
    ) public returns (bool) {
        require(
            doctorsRegistered[_doctorAddress] == false,
            "Doctor is already added."
        );
        uint256 _doctorid = _doctorIds.current();
        _doctorIds.increment();
        doctorsRegistered[_doctorAddress] = true;

        doctors[_doctorid] = Doctor(
            _doctorid,
            _doctorAddress,
            DoctorType(_doctorType),
            _metaData,
            Status(_status),
            Sex(_gender),
            block.timestamp,
            msg.sender
        );

        emit DoctorEvents(
            _doctorid,
            "Doctor Added",
            _doctorAddress,
            msg.sender,
            block.timestamp
        );
        return true;
    }

    // take back permissions -- delete authorization of doctors
    function deRegisterDoctor(address _doctorAddress)
        public
        only_owner
        returns (bool)
    {
        // if doctor is authorized
        require(
            doctorsRegistered[_doctorAddress] == true,
            "Cannot remove the Doctor who is not active."
        );
        doctorsRegistered[_doctorAddress] = false;
        emit DoctorEvents(
            0,
            "Doctor Deregistered",
            _doctorAddress,
            msg.sender,
            block.timestamp
        );
        return true;
    }

    //Insert the record
    function insertRecords(
        address _patientAddr,
        //address _doctorAddress,
        uint256 _patientId,
        uint256 _doctorId,
        string memory _hash,
        RecordType _recordType,
        RecordStatus _recordStatus,
        Sex _gender,
        Role _roleType
    ) public returns (bool) {
        require(patientToDoctor[_patientId][_doctorId] == false,"No Authorization provided");
        uint256 _recordid = _recordIds.current();
        _recordIds.increment();

        records[_recordid] = Record(
            _recordid,
            _patientAddr,
            RecordType(_recordType),
            _hash,
            RecordStatus(_recordStatus),
            Sex(_gender),
            block.timestamp,
            msg.sender,
            Role(_roleType)
        );
        emit RecordEvents(
            _recordid,
            "Record has been inserted",
            _patientAddr,
            msg.sender,
            block.timestamp
        );
        return true;
    }


    //requestToView
    function requestToView(
        address _oracle,
        string memory _jobId,
        address _patientAddr,
        string memory _careGiverEmail
    ) public returns (bytes32 requestId) {
        uint256 _viewId = _viewIds.current();
        Plugin.Request memory request = buildPluginRequest(
            stringToBytes32(_jobId),
            address(this),
            this.fulfillPermission.selector
        );
        request.add("careGiverEmail", _careGiverEmail);
        //Random Number generate logic comes here, then pass it on
        // Once this random number passed to User via email.
        // User should enter the number they received via email,
        // This will be verified in external adapter & verify if both the numbers are matching
        // if yes, then the request will be processed
        //uint256 _randomNumber = 52525; // Dummy data
        uint256 randomHash = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) / 100000;
        uint256 _randomNumber = randomHash / 100000; // Dummy data randomHash % 100000;
        
        request.addUint("randomNumber", _randomNumber);

        documentLogs[_viewId] = DocumentLogs(
            _viewId,
            _patientAddr,
            block.timestamp,
            msg.sender,
            _randomNumber,
            false
        );

        requestId = sendPluginRequestTo(_oracle, request, ORACLE_PAYMENT);
        documentLogRequestIds[requestId] = documentLogs[_viewId];
        emit requestCreated(msg.sender, stringToBytes32(_jobId), requestId);
    }

    //callBack function
    function fulfillPermission(bytes32 _requestId, uint256 _otp)
        public
        recordPluginFulfillment(_requestId)
    {
        DocumentLogs memory docLogs = documentLogRequestIds[_requestId];
        if (docLogs.otp == _otp) {
            docLogs.processed = true;
            emit RequestPermissionFulfilled(_requestId, _otp);
        }
    }

    //String to bytes to convert jobid to bytest32
    function stringToBytes32(string memory source)
        private
        pure
        returns (bytes32 result)
    {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
        assembly {
            result := mload(add(source, 32))
        }
    }
    //Grant access to doctors
    // function grantAccessToDoctor(address entity_id) public checkPatient(msg.sender) checkDoctor(_doctorAddress) {
    //     patient storage p = patients[msg.sender];
    //     doctor storage d = doctors[doctor_id];
    //     require(patientToDoctor[msg.sender][doctor_id] < 1);// this means doctor already been given access
        
    //     uint pos = p.doctor_list.push(doctor_id);// new length of array
    //     gpos = pos;
    //     patientToDoctor[msg.sender][doctor_id] = pos;
    //     d.patient_list.push(msg.sender);
    // }
    
    //Grant access to doctor to update and upload file
    function grantAccessToDoctor(
        uint256 _doctorId,
        uint256 _patientId
    ) public checkPatient(_patientId) returns(bool){
        require(patientToDoctor[_patientId][_doctorId] == false,"Doctor has already been authorised");
        patientToDoctor[_patientId][_doctorId] = true;
        return true;
    }

    //Storing IPFS file info
    function uploadFile(
        // string memory _file_name, 
        // string memory _file_type, 
        string memory _fileHash, 
        uint256 _doctorId, 
        uint256 _patientId ) public returns (bool) {
        //Patient memory p = patients[_patientId];
        //emit debugConsole(p.patientId);
        //require(patientToDoctor[_patientId][_doctorId] == true, "No permission to upload file");
        require(patientToFile[_patientId][_fileHash] == false, "Patient file exisits, cannot overwite!");

        //hashToFile[_fileHash] = filesInfo({file_name:_file_name, file_type:_file_type});
        //uint pos = p.files.push(_fileHash);
        patientToFile[_patientId][_fileHash] = true;
        // emit FileUpload(_file_name, _patientAddress);
        return true;
    }

}