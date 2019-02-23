pragma solidity ^0.4.23;

contract Request{
    
    uint public id;
    bool approved;
    mapping(address => bool) voted;
  
    function isApproved()public view returns(bool){
        return approved;
    }
    
    function approve()public returns(bool);
    function updateApprovers(address newApprover) public;
}