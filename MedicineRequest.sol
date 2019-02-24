pragma solidity ^0.4.23;
import './Request.sol';

contract MedicineRequest is Request{
    
    string medicineId;
    string name;
    string description;
    uint value;
    uint validity;
    
    address[] approvers;
    uint approveCounts;
    
    event ApprovedBy(address approver);
    event Approved(string medicineId);
    event NewApprover(address newApprover);
    
    modifier notApproved{
        require(!approved, "This has already been approved");
        _;
    }
    
    modifier hasntVoted{
        require(!voted[msg.sender], "has already voted");
        _;
    }
    
    modifier onlyAprover{
        
     bool isAprover = false;
     
    for(uint i = 0; i < approvers.length; i++){
        if(approvers[i] == msg.sender){
            isAprover = true;
        }
     }
    require(isAprover);
    _;
    }
    
    constructor(uint _id, string _medicineId, string _name, string _description, uint _value, uint _validity, address[] _approvers)public{
        
        id = _id;
        medicineId = _medicineId;
        name = _name;
        description = _description;
        value = _value;
        validity = _validity;
        approvers = _approvers;
        approveCounts = 0;
        approved = false;
    }
    
    function getMedicineName()public view returns(string){
        
        return name;
    }
    
    function getMedicineDescription()public view returns(string){
        
        return description;
    }
    
    function getMedicineValue()public view returns(uint){
        
        return value;
    }
    
    function getMedicineValidity()public view returns(uint){
        
        return validity;
    }
    
    function getMedicineId()public view returns(string){
        
        return medicineId;
    }
    
    function approve()public hasntVoted notApproved onlyAprover returns(bool){
        
        approveCounts += 1;
        voted[msg.sender] = true;
        emit ApprovedBy(msg.sender);
        
        if(approveCounts >= approvers.length / 2){
            approved = true;
            emit Approved(medicineId);
        }
        
        return approved;
    }
    
    function updateApprovers(address newApprover)public{
        
        approvers.push(newApprover);
        emit NewApprover(newApprover);
    }
}