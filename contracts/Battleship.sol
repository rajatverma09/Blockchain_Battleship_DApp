pragma solidity ^0.5.12;

contract Battleship
{
    
    uint bit_amount = 1 ether;
    enum GameState { Created, SettingUp, Playing, Finished }
    
    struct Game{
        string player1Name;
        string player2Name;
        address player1;
        address player2;
        address turn;
        address winner;
        uint game_house;
        GameState state;
        mapping(address => int8[10][10]) playerGrids;
        mapping(address => bool[5]) isShipPlaced;
        mapping(address => uint8) nShipsPlaced;
        mapping(address => uint8[5]) nHitsToShip;
        mapping(address => uint8) nShipsSunk;
    }
    
    mapping(address => string) public playerName;
    mapping(address => bool) public isPlayerName;
    mapping(string => Game) public gamelist;
    mapping(string => bool) public isGamelist;
    int8[10][10] otherPlayerBoard;

    //modifiers
    modifier isState(string memory gameId, GameState state)
    {
        require(state == gamelist[gameId].state, "State mismatch");
        _;
    }
    modifier isPlayer(string memory gameId) 
    {
        require(msg.sender == gamelist[gameId].player1 || msg.sender == gamelist[gameId].player2, "You are not player in this game");
        _;
    }
    modifier isTurn(string memory gameId, address me)
    {
        require(gamelist[gameId].turn == me, "Not your turn");
        _;
    }

    //utility  functions
    function stringToBytes32(string memory source) pure private returns (bytes32 result) 
    {
        assembly 
        {
            result := mload(add(source, 32))
        }
    }
    function initialiseBoard(string memory  gameId, address player) isState(gameId, GameState.Created) internal 
    {
        for(uint8 i = 0; i < 10; i++) 
        {
            for(uint8 j = 0; j < 10; j++) 
            {
                gamelist[gameId].playerGrids[player][i][j] = 0;
            }
        }
    }
    function showBoard(string memory gameId) isPlayer(gameId) public view returns(int8[10][10] memory) 
    {
        return gamelist[gameId].playerGrids[msg.sender];
    }
    function findOtherPlayer(string memory gameId,address player) internal view returns(address)
    {
        if(player == gamelist[gameId].player1) return gamelist[gameId].player2;
        return gamelist[gameId].player1;
    }
    function toss(uint8 range) private view returns(uint8)
    {
         return uint8(uint(keccak256(abi.encodePacked(now, msg.sender, block.timestamp, block.difficulty))) % range);
    }
    function getWinner(string memory gameId, address payable me) isPlayer(gameId) isState(gameId,GameState.Finished) public returns(string memory)
    {
        address payable otherPlayer = address(uint160(findOtherPlayer(gameId, me)));
        if(gamelist[gameId].winner == me)
        {
            me.transfer(gamelist[gameId].game_house);
            return "You Win";
        }
        else if(gamelist[gameId].winner == otherPlayer)
        {
            otherPlayer.transfer(gamelist[gameId].game_house);
            return "You Lose";
        }
    }
    function getGameState(string memory gameId) isPlayer(gameId) public view returns(string memory)
    {
        if(gamelist[gameId].state == GameState.Created)
            return "Created";
        if(gamelist[gameId].state == GameState.SettingUp)
            return "SettingUp";
        if(gamelist[gameId].state == GameState.Playing)
            return "Playing";
        if(gamelist[gameId].state == GameState.Finished)
            return "Finished";
    }
    function isShipSunk(string memory gameId, uint8 shipId, address me) private view returns(bool)
    {
        uint8 h = gamelist[gameId].nHitsToShip[me][shipId - 1];
        if(shipId == 1 && h == 5)
            return true;
        if(shipId == 2 && h == 4)
            return true;
        if(shipId == 3 && h == 3)
            return true;
        if(shipId == 4 && h == 3)
            return true;
        if(shipId == 5 && h == 2)
            return true;
        return false;
    }
    function getShipLength(uint8 shipId) private pure returns(uint8)
    {
        if(shipId == 1) // Carrier
            return 5;
        else if(shipId == 2) // Battleship
            return 4;
        else if(shipId == 3 || shipId == 4) // Destroyer or Submarine
            return 3;
        else if(shipId == 5) // Patrol Boat
            return 2;
        return 0;
    }

    
    
    function CreateGame(string memory name, string memory  gameId) public  payable
    {
        require(!isGamelist[gameId], "Game already exists");
        require(0 < bytes(name).length && bytes(name).length <= 30, "Enter Valid name!");
        require(msg.value == bit_amount, "Enter 1 ether to player");
        // require(!isPlayerName[msg.sender], "player already exist");
        
        // playerName[msg.sender] = name;
        // isPlayerName[msg.sender] = true;
        gamelist[gameId] = Game(name, "", msg.sender, address(0), address(0), address(0), msg.value, GameState.Created);
        isGamelist[gameId] = true;
        initialiseBoard(gameId, msg.sender);
    }
    
    function JoinGame(string memory name, string memory  gameId) isState(gameId, GameState.Created) public payable
    {
        require(isGamelist[gameId], "Game not exists");
        require(gamelist[gameId].player2 == address(0), "Room not free!");
        require(0 < bytes(name).length && bytes(name).length <= 30, "Enter Valid name!");
        require(msg.value == bit_amount, "Enter 1 ether to player");
        // require(!isPlayerName[msg.sender], "player already exist");
        
        // playerName[msg.sender] = name;
        // isPlayerName[msg.sender]  = true;
        gamelist[gameId].player2 = msg.sender;
        gamelist[gameId].player2Name = name;
        gamelist[gameId].game_house += msg.value;
        gamelist[gameId].state = GameState.SettingUp;
        initialiseBoard(gameId, msg.sender);
    }
    
    function PlaceShips(string memory gameId, uint8 shipId, uint8 startX, uint8 endX, uint8 startY, uint8 endY) isPlayer(gameId) isState(gameId,GameState.SettingUp) public
    {
        uint8 slen = getShipLength(shipId);
        require(slen != 0, "Invalid shipId");
        require(!gamelist[gameId].isShipPlaced[msg.sender][uint8(shipId - 1)], "You already placed this Ship");
        require(startX == endX || startY == endY, "Place ships only vetically or horizontally");
        require(startX < endX || startY < endY);
        require(startX  < 10 && startX  >= 0 &&
                endX    < 10 && endX    >= 0 &&
                startY  < 10 && startY  >= 0 &&
                endY    < 10 && endY    >= 0, "Range out of bound");
        
        uint8 boatLength = 1;
        if(startX == endX) 
        {
            int DY = int(startY) - int(endY);
            if(DY >= 0)
                boatLength += uint8(DY);
            else
                boatLength += uint8(-DY);
        }
        else if(startY == endY) 
        {
            int DX = int(startX) - int(endX);
            if(DX >= 0)
                boatLength += uint8(DX);
            else
                boatLength += uint8(-DX);
        }
        require(boatLength == slen, "length mismatch");
        for(uint8 x = startX; x <= endX; x++) {
            for(uint8 y = startY; y <= endY; y++) {
                require(gamelist[gameId].playerGrids[msg.sender][x][y] == 0, "Can't overlap ships");
            }   
        }
        require(gamelist[gameId].nShipsPlaced[msg.sender] < 5, "Let your opponent place the ships");
        
        gamelist[gameId].isShipPlaced[msg.sender][uint8(shipId - 1)] = true;
        for(uint8 x = startX; x <= endX; x++) {
            for(uint8 y = startY; y <= endY; y++) {
                gamelist[gameId].playerGrids[msg.sender][x][y] = int8(shipId);
            }   
        }
        gamelist[gameId].nShipsPlaced[msg.sender]++;
        if(gamelist[gameId].nShipsPlaced[gamelist[gameId].player1] == 5 && gamelist[gameId].nShipsPlaced[gamelist[gameId].player2] == 5)
        {
            if(toss(2) == 0)
                gamelist[gameId].turn = msg.sender;
            else
                gamelist[gameId].turn = findOtherPlayer(gameId, msg.sender);
            gamelist[gameId].state = GameState.Playing;
        }
    }
    
    function whoseTurn(string memory gameId) isPlayer(gameId) isState(gameId,GameState.Playing) public view returns(string memory)
    {
        if(gamelist[gameId].turn == msg.sender)
            return "Your turn";
        else
            return "Opponent's turn";
    }
    
    
    function makeMove(string memory gameId, uint8 x, uint8 y) isPlayer(gameId) isState(gameId,GameState.Playing) isTurn(gameId, msg.sender) public
    {
        address otherPlayer = findOtherPlayer(gameId,msg.sender);
        require(gamelist[gameId].playerGrids[otherPlayer][x][y] >= 0, "You already hit that place");
        if(gamelist[gameId].playerGrids[otherPlayer][x][y] > 0) 
        {
            gamelist[gameId].nHitsToShip[msg.sender][uint8(gamelist[gameId].playerGrids[otherPlayer][x][y] - 1)]++;   
            if(isShipSunk(gameId, uint8(gamelist[gameId].playerGrids[otherPlayer][x][y]), msg.sender))
            {
                gamelist[gameId].nShipsSunk[msg.sender]++;
            }
            gamelist[gameId].playerGrids[otherPlayer][x][y] = -1 * gamelist[gameId].playerGrids[otherPlayer][x][y];
        }
        else
        {
            gamelist[gameId].playerGrids[otherPlayer][x][y] = -10;
        }
        if(gamelist[gameId].nShipsSunk[msg.sender] == 5)
        {
            gamelist[gameId].state = GameState.Finished;   
            gamelist[gameId].winner = msg.sender;
        }
        gamelist[gameId].turn = otherPlayer;
    }
    
    function showOtherPlayerBoard(string memory gameId) isPlayer(gameId) public returns(int8[10][10] memory){
        require(gamelist[gameId].state == GameState.Playing || gamelist[gameId].state == GameState.Finished);
        address otherPlayer = findOtherPlayer(gameId,msg.sender);
        int8[10][10] memory otherGrid = gamelist[gameId].playerGrids[otherPlayer];
        for(uint8 i = 0; i < 10; i++) {
            for(uint j = 0; j < 10; j++) {
                if(otherGrid[i][j] > 0)
                {
                    otherPlayerBoard[i][j] = 0;
                }
                else
                {
                    otherPlayerBoard[i][j] = otherGrid[i][j];
                }
            }
        }
        return otherPlayerBoard;
    }
    
    
}