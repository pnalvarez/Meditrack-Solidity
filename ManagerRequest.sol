pragma solidity ^0.4.23;
import './Request.sol';

contract ManagerRequest is Request{
    
    address public newManager;
    address[] public approvers;
    uint public approveCounts;
    
    event ApprovedBy(address approver);
    event Approved(uint approveCounts);
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
    
    constructor(uint _id, address _newManager, address[] _approvers)public{
        
        id = _id;
        newManager = _newManager;
        approvers = _approvers;
        approveCounts = 0;
        approved = false;
    }
    
    function getNewManager()public view returns(address){
        
        return newManager;
    }
    
    function approve()public hasntVoted notApproved onlyAprover returns(bool){
        
        approveCounts += 1;
        voted[msg.sender] = true;
        emit ApprovedBy(msg.sender);
        
        if(approveCounts >= approvers.length / 2){
            approved = true;
            emit Approved(approveCounts);
        }
        
        return approved;
    }
    
    function updateApprovers(address newApprover)public{
        
        approvers.push(newApprover);
        emit NewApprover(newApprover);
    }
}