pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import './TransferRequest.sol';
import './ManagerRequest.sol';
import './UserRequest.sol';
import './MedicineRequest.sol';

contract Supplychain{

    enum Function{

        Nothing, Productor, Stock, Transport, CirurgicCenter, Seller,  Buyer
    }
    struct Receive{ 

        string uuid;
        string id;
        uint timestamp;
        address from;
        address to;
    }
  
    struct Wallet{
        
        bool isManager;
        mapping(string => uint) medicines;
        mapping(string => bool) products;
        uint creationTime;
        Function func; 
    }

    struct Medicine{

        string name; 
        string description;
        bool initialized;
        uint value; 
        uint validity;
    }
    struct Product{

        string id; 
        address owner;
        bool isValid; 
        uint creationTime;
        address[] path;
        uint[] timestamps;
    }

    struct Sinister {

        string title;
        string description;
        string envolvedProduct; 
        address responsible; 
        uint timestamp; 
    }


    address[] public managers;

    mapping(string => Medicine)private medicines;
    mapping(address => Wallet)private wallets;
    mapping(string => Product)private products;
    mapping(string => bool)private productExist;
    
    string[]public medicineNames;
    string[]public allProducts;
    address[]public allWallets;
    
    mapping(address => bool)private participates;
    uint public begin;
    mapping(address => Receive[]) receives;
    mapping(address => Sinister[]) sinisters;
    mapping(address => bool) isInAlfaCenter;
    mapping(string => Function) stringToFunction;
    mapping(string => bool) productWasDeleted;
    
    ManagerRequest[] managerRequests;
    TransferRequest[] transferRequests;
    UserRequest[] userRequests;
    MedicineRequest[] medicineRequests;
    
    Sinister[] public allSinisters;

    event medicineCreated(string id); 
    event medicineTransfered(string uuid, string id, address from, address to);
    event productGenerated(address by, string uuid, string id);
    event changeSent(address to, uint change); 
    event medicineBought(address by, string uuid); 
    event FunctionDesignated(address to, Function f); 
    event ProductOutOfValidity(string uuid, string id, uint time); 
    event NewSinister(string title, string uuid, address responsible); 
    event PathIncremented(string uuid, string id, address adr, uint timestamp); 
    event DiscardedProduct(string uuid, address lastowner, uint timestamp);
    event ThrowProductAway(string uuid, address by, uint timestamp);
    event NewRequest();
    event NewManagerApproved(address newManager);

    modifier onlyManager{
        require(wallets[msg.sender].isManager, "only manager");
        _;
    }

    modifier only(Function f){
        require(wallets[msg.sender].func == f, "This person is not applied here");
        _;
    }

    modifier productExists(string uuid){
         require(productExist[uuid], "This product does not exist");
        _;
    }

    modifier productOwner(address a, string uuid){
        string memory message;

        if(msg.sender == a){
            message = "You dont have this product";
        }
        else{
            message = "This person doesnt have this product";
        }

        require(wallets[a].products[uuid], message);
        _;
    }

    modifier personExists(address a){
        string memory message;

        if(msg.sender == a){
            message = "You are not a participant";
        }
        else{
            message = "This person does not exist";
        }

        require(participates[a], message);
        _;
    }

    modifier validProduct(string uuid){
        require(products[uuid].isValid, "Only valid producsts here");
        _;
    }

    modifier checkTime{
        checkValidity();
        _;
    }

    modifier inexistantWallet(address adr){
      require(!participates[adr], "This wallet has already been created");
      _;
    }

    modifier supplychainRule(address from, address to){ 
      bool[5] memory rules = 
      [wallets[from].func == Function.Productor && wallets[to].func == Function.Transport,
      wallets[from].func == Function.Transport && wallets[to].func == Function.Stock,
      wallets[from].func == Function.Stock && wallets[to].func == Function.Stock,
      wallets[from].func == Function.Stock && wallets[to].func == Function.CirurgicCenter,
      wallets[from].func == Function.Stock && wallets[to].func == Function.Seller];

       bool ok = false;

       for(uint i = 0; i< rules.length; i++){
         if(rules[i]){
           ok = true;
         }
       }
      require(ok, "It does not agree with the supplychain rules");
      _;
    }

    constructor()public{
        managers.push(msg.sender); //managers.push(msg.sender);
        begin = now;
        wallets[msg.sender] = Wallet(true,now, Function.Productor);
        participates[msg.sender] = true;

        stringToFunction["Nothing"] = Function.Nothing;
        stringToFunction["Productor"] = Function.Productor;
        stringToFunction["Stock"] = Function.Stock;
        stringToFunction["Transport"] = Function.Transport;
        stringToFunction["CirurgicCenter"] = Function.CirurgicCenter;
        stringToFunction["Seller"] = Function.Seller;
        stringToFunction["Buyer"] = Function.Buyer;
    }

   function designateFunction(address wallet, string func)private checkTime{ 

       wallets[wallet].func = stringToFunction[func];
       emit FunctionDesignated(wallet, stringToFunction[func]);
   }

   function searchReceive(address a, string uuid)private view returns(int){

       for(int i = 0; i < int(receives[a].length); i++){
           uint ui = uint(i);
           Receive memory r = receives[a][ui];
           if(compareStrings(r.uuid, uuid)){
               return i;
           }
       }
       return -1;
   }

   function transferOperation(address from, string uuid, address to)private
   returns(Receive){

       uint timestamp = now;
       string memory id = products[uuid].id;

       incrementPath(uuid, to);

       wallets[from].products[uuid] = false;
       wallets[from].medicines[id] -= 1;

       products[uuid].owner = to;

       wallets[to].products[uuid] = true;
       wallets[to].medicines[id] += 1;

       Receive memory receive = Receive(uuid, id, timestamp, from, to);

       receives[to].push(receive);

       emit medicineTransfered(uuid, id, from, to);

       return receive;
   }
   function sendMedicine(string uuid)private{ 

        string memory id = products[uuid].id;

       wallets[msg.sender].products[uuid] = false;
       wallets[msg.sender].medicines[id] -= 1;
   }

   function sendChange()private returns(uint){ 
       uint balance = address(this).balance;
       msg.sender.transfer(balance);

       emit changeSent(msg.sender, balance);

       return balance;
   }

   function compareStrings (string a, string b)private pure returns (bool){
       if(bytes(a).length != bytes(b).length){
           return false;
       }
       else{
           return keccak256(bytes(a)) == keccak256(bytes(b));
       }
  }

  function searchProductIndex(string uuid)public view returns(int){ 

      for(int i = 0; i < int(allProducts.length); i++){
        uint ui = uint(i);

        string memory product = allProducts[ui];

        if(compareStrings(product,uuid)){
          return i;
        }
      }
      return -1;
  }

  function checkValidity()private{ 

      for(uint i = 0; i < allProducts.length; i++){

          Product storage product = products[allProducts[i]];

           if(product.isValid){
               uint timestamp = now - product.creationTime;

               if(timestamp >= medicines[product.id].validity){
                    product.isValid = false;
                    emit ProductOutOfValidity(allProducts[i], product.id, timestamp - medicines[product.id].validity);
               }
           }
      }
  }

  function incrementPath(string uuid, address adr)private productExists(uuid){

       uint time = now;

       products[uuid].path.push(adr);
       products[uuid].timestamps.push(time);

       emit PathIncremented(uuid, products[uuid].id, adr, time);
  }

  function discardProduct(string uuid)private productExists(uuid){ 

      address owner = getOwnerof(uuid);
      string storage id = products[uuid].id;

      wallets[owner].medicines[id] -= 1;
      wallets[owner].products[uuid] = false;
      products[uuid].owner = 0x0;
      productExist[uuid] = false;
      productWasDeleted[uuid] = true;

      int index = searchProductIndex(uuid);

      if(index >= 0){
        uint ui = uint(index);
        delete allProducts[ui];
      }

      uint timestamp = now;

      emit DiscardedProduct(uuid, owner, timestamp);
  }
   function medicineCreate(string id, string _name, string _description, uint _value, uint _validity)
   private{
       require(!medicines[id].initialized, "Medicine already exists");

       medicines[id] = Medicine(_name, _description, true, _value, _validity);
       medicineNames.push(id);

       emit medicineCreated(id);
   }

   function createWallet(address adr, string f)private{

       wallets[adr] = Wallet(false,now,stringToFunction[f]);
       participates[adr] = true;
       allWallets.push(adr);
   }

   function medicineGenerate(string uuid, string id)public only(Function.Productor) 
   checkTime{
       require(medicines[id].initialized, "medicine does not exist");
       require(!productExist[uuid], "product already generated");
       require(!productWasDeleted[uuid], "product has already existed and been deleted at some point");

       uint time = now;
       wallets[msg.sender].medicines[id] += 1;
       productExist[uuid] = true;
       wallets[msg.sender].products[uuid] = true;

       address[] memory array;
       uint[] memory times;
       products[uuid] = Product(id, msg.sender, true, time, array, times);

       incrementPath(uuid, msg.sender);
       allProducts.push(uuid);

       emit productGenerated(msg.sender,uuid,id);
   }


   function buyMedicine(address from, string uuid)public payable
   only(Function.Buyer)
   productExists(uuid) productOwner(from, uuid) checkTime
   validProduct(uuid) 
   returns(uint){

       require(msg.value >= medicines[products[uuid].id].value, "Not enough balance");
       require(wallets[from].func == Function.Seller, "Only seller can sell");

       uint change = sendChange();
       transferOperation(from, uuid, msg.sender);

       emit medicineBought(msg.sender, uuid);

       return change;
   }
   
   function addNewMedicineRequest(string id, string name, string description, uint value, uint validity)public
   onlyManager
   checkTime{
       require(!medicines[id].initialized, "Medicine already exists");
       
       MedicineRequest request = new MedicineRequest(medicineRequests.length, id, name, description, value, validity, managers);
       medicineRequests.push(request);
       
       emit NewRequest();
   }
   
   function approveNewMedicineRequest(uint id)public onlyManager checkTime{
       
       require(medicineRequests.length > id, "Request invalid");
       
       medicineRequests[id].approve();
       
       if(medicineRequests[id].isApproved()){
           
           string memory medicineId = medicineRequests[id].getMedicineId();
           string memory name = medicineRequests[id].getMedicineName();
           string memory description = medicineRequests[id].getMedicineDescription();
           uint value = medicineRequests[id].getMedicineValue();
           uint validity = medicineRequests[id].getMedicineValidity();
           
           medicineCreate(medicineId, name, description, value, validity);
       }
   }
   
   function addNewUserRequest(address adr, string f)public
   onlyManager
   inexistantWallet(adr)
   checkTime{
       
       UserRequest request = new UserRequest(userRequests.length, adr, f, managers);
       userRequests.push(request);
       
       emit NewRequest();
   }
   
   function approveNewUserRequest(uint id)public checkTime{
       require(userRequests.length > id, "Request invalid");
       
       userRequests[id].approve();
       
       if(userRequests[id].isApproved()){
           
           address newUser = userRequests[id].getNewUser();
           string memory func = userRequests[id].getFunc();
           
           createWallet(newUser, func);
       }
   }
   
   function addNewManagerRequest(address newManager)public
   onlyManager
   personExists(newManager)
   checkTime {
       require(!wallets[newManager].isManager, "he is already a manager");
       
       ManagerRequest request = new ManagerRequest(managerRequests.length, newManager, managers);
       managerRequests.push(request);
       
       emit NewRequest();
   }
   
   function approveNewManagerRequest(uint id)public checkTime{
       require(managerRequests.length > id, "Request invalid");
       
       managerRequests[id].approve();
       
       if(managerRequests[id].isApproved()){
           
           address newManager = managerRequests[id].getNewUser();
           managers.push(newManager);
           
           for(uint i = 0; i < managerRequests.length; i++){
               if(!managerRequests[i].isApproved()){
                   managerRequests[i].updateApprovers(newManager);
               }
           }
           
           emit NewManagerApproved(newManager);
       }
   }
   
   function newTransferRequest(string uuid, address to)public
   validProduct(uuid)
   productOwner(msg.sender, uuid)
   supplychainRule(msg.sender, to)
   checkTime{
       
       TransferRequest request = new TransferRequest(transferRequests.length, to, uuid, msg.sender);
       transferRequests.push(request);
       
       emit NewRequest();
   }
   
   function approveTransferRequest(uint id)public checkTime{
       require(transferRequests.length > id, "Request invalid");
       
       transferRequests[id].approve();
       
       string memory uuid = transferRequests[id].getProductId();
       address to = transferRequests[id].getApprover();
       
       transferOperation(msg.sender, uuid, to);
   }

   function notifySinister(string _title, string _description, string _product)public checkTime
   productExists(_product) productOwner(msg.sender, _product) returns(Sinister){

       uint _timestamp = now;
       Sinister memory sinister = Sinister(_title,_description,_product,msg.sender,_timestamp);
       sinisters[msg.sender].push(sinister);
       allSinisters.push(sinister);
       
       discardProduct(_product);

       emit NewSinister(_title, _product, msg.sender);

       return sinister;
   }

   function throwAway(string uuid)public checkTime productOwner(msg.sender, uuid){

       discardProduct(uuid);
       uint timestamp = now;

       emit ThrowProductAway(uuid, msg.sender, timestamp);
   }

   function getOwnerof(string uuid)public view returns(address){
       return products[uuid].owner;
   }

   function getReceive(string uuid)public view returns(Receive){
       int index = searchReceive(msg.sender, uuid);

       require(index >= 0);
       uint ui = uint(index);
       return receives[msg.sender][ui];
   }

   function trackProduct(string uuid, uint timestamp)public view
    productExists(uuid) returns(address){
      uint currentTime = now;

      require(timestamp <= currentTime, "Please enter a valid time");

      uint[] memory timestamps = products[uuid].timestamps;

      for(uint i = 0; i < timestamps.length - 1; i++){
        if(timestamps[i] <= timestamp && timestamp <= timestamps[i+1]){
          return products[uuid].path[i];
        }
      }
      return products[uuid].owner;
   }

   function getMedicineName(string id)public view returns(string){
     return medicines[id].name;
   }
   function getMedicineDescription(string id)public view returns(string){
     return medicines[id].description;
   }
   function getMedicineValue(string id)public view returns(uint){
     return medicines[id].value;
   }
   function getMedicineValidity(string id)public view returns(uint){
     return medicines[id].validity;
   }

   function getWalletMedicineQtd(address adr, string id)public view returns(uint){
      return wallets[adr].medicines[id];
   }

   function getWalletFunction(address adr)public view returns(string){

     if(wallets[adr].func == Function.Productor){
       return "Productor";
     }
     else if(wallets[adr].func == Function.Stock){
       return "Stock";
     }
     else if(wallets[adr].func == Function.Transport){
       return "Transport";
     }
     else if(wallets[adr].func == Function.CirurgicCenter){
       return "Cirurgic center";
     }
     else if(wallets[adr].func == Function.Nothing){
       return "Nothing";
     }
     else if(wallets[adr].func == Function.Seller){
       return "Seller";
     }
     else{
       return "Buyer";
     }
   }
   function walletHasProduct(address adr, string uuid)public view returns(bool){
      return wallets[adr].products[uuid];
   }
   function getWalletCreationTime(address adr)public view returns(uint){
       return wallets[adr].creationTime;
   }

   function getProductExist(string uuid)public view returns(bool){
     return productExist[uuid];
   }

   function getProductId(string uuid)public view returns(string){
     return products[uuid].id;
   }
   function getProductOwner(string uuid)public view returns(address){
     return products[uuid].owner;
   }
   function getProductValid(string uuid)public view returns(bool){
     return products[uuid].isValid;
   }
   function getProductCreationTime(string uuid)public view returns(uint){
     return products[uuid].creationTime;
   }
   function getProductCreator(string uuid)public view returns(address){
       return products[uuid].path[0];
   }
   function getTimestamp(string uuid, uint index)public view returns(uint){
       return products[uuid].timestamps[index];
   }

   function getReceiveProduct(uint index, address adr)public view returns(string){
     return receives[adr][index].uuid;
   }
   function getReceiveMedicine(uint index, address adr)public view returns(string){
     return receives[adr][index].id;
   }
   function getReceiveTimestamp(uint index, address adr)public view returns(uint){
     return receives[adr][index].timestamp;
   }
   function getReceiveFrom(uint index, address adr)public view returns(address){
     return receives[adr][index].from;
   }
   function getReceiveTo(uint index, address adr)public view returns(address){
     return receives[adr][index].to;
   }
   function getReceivesQtd(address adr)public view returns(uint){
       return receives[adr].length;
   }

   function getSinisterTitle(uint index, address adr)public view returns(string){
        return sinisters[adr][index].title;
   }
   function getSinisterDescription(uint index, address adr)public view returns(string){
        return sinisters[adr][index].description;
   }
   function getSinisterEnvolvedProduct(uint index, address adr)public view returns(string){
        return sinisters[adr][index].envolvedProduct;
   }
   function getSinisterResponsible(uint index, address adr)public view returns(address){
        return sinisters[adr][index].responsible;
   }
   function getSinisterTimestamp(uint index, address adr)public view returns(uint){
        return sinisters[adr][index].timestamp;
   }
   function getSinistersQtd(address adr)public view returns(uint){
       return sinisters[adr].length;
   }
   function getBalanceof(address adr)public view returns(uint){
     return adr.balance;
   }

   function productStillExist(string uuid)public view returns(bool){

      int index = searchProductIndex(uuid);

      return index >= 0;

   }

   function getMedicineNamesTotal()public view returns(uint){
    return medicineNames.length;
}
  function getAllProductsTotal()public view returns(uint){
    return allProducts.length;
}
  function getAllWalletsTotal()public view returns(uint){
      return allWallets.length;
  }
  
}