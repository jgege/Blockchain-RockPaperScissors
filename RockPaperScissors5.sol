pragma solidity ^0.4.0;
contract RockPaperScissors {

    address owner;
    uint numberOfGames = 0;
    uint[] activeGamesIdList;
    mapping(uint => Game) listOfGames;

    struct Game {
        address player1;
        address player2;
        
        uint8 winner;
        
        /**
         * A deposit by player1 and player2
         */
        uint256 deposit; // in wei
        
        uint256 originalDeposit;
        
        /**
         * The prize set by player1
         */
        uint256 prize; // in wei
        
        /**
         * 0 - waiting for a player to join
         * 1 - waiting for player 1 to reveal
         * 2 - game ended
         * 3 - deleted
         */
        uint8 gameState;
        
        /**
         * player 1's choice in a hashed form
         */
        bytes32 choiceHash; 
        
        /**
         * Choices
         * 1 - rock
         * 2 - paper
         * 3 - scissors
         */
        uint8 player2Choice;
    }
    
    /**
     * Events
     */ 
    event WaitingForPlayerToJoin(uint gameId);
    event PlayerJoinedEvent(uint gameId);
    event GameEndEvent(uint gameId);
    event DeletedEvent(uint gameId);
    
    /**
     * Modifiers
     */
    modifier onlyByPlayer1(uint gameId)
    {
        Game memory g = listOfGames[gameId];
        require(msg.sender == g.player1);
        _;
    }
    
    // Useful at game state 2 when we do nt have player2 yet but player1 can't do something
    modifier notByPlayer1(uint gameId)
    {
        Game memory g = listOfGames[gameId];
        require(msg.sender != g.player1);
        _;
    }
    
    modifier onlyByPlayer2(uint gameId)
    {
        Game memory g = listOfGames[gameId];
        require(msg.sender == g.player2);
        _;
    }
    
    // Game started, waiting for a player to join
    modifier atGameStateStarted(uint gameId)
    {
        Game memory g = listOfGames[gameId];
        require(g.gameState == 0);
        _;
    }
    
    // Second player joined, waiting for player1 to reveal
    modifier atGameStateNeedToReveal(uint gameId)
    {
        Game memory g = listOfGames[gameId];
        require(g.gameState == 1);
        _;
    }
    
    // Game ended
    modifier atGameStateEnd(uint gameId)
    {
        Game memory g = listOfGames[gameId];
        require(g.gameState == 2);
        _;
    }
    
    modifier gameExists(uint gameId)
    {
        require(listOfGames[gameId].player1 != address(0));
        _;
    }
    
    /**
     * Consturctor
     */
    function RockPaperScissors() public
    {
        owner = msg.sender;
    }
    
    /**
     * Create new game
     */
    function create(uint256 _initialPrize, bytes32 _hash) public payable returns(uint)
    {
        uint256 fundsReceived = msg.value;

        // Prize has to be higher than 0
        require((_initialPrize > 0));
        
        // Prize has to be at least 2 times higher than the funds received
        // to motivate player1 to reveal the choice
        require((fundsReceived >= (_initialPrize*2)));

        Game memory newGame = Game({
            player1: msg.sender,
            player2: address(0),
            choiceHash: _hash,
            deposit: fundsReceived,
            originalDeposit: (fundsReceived-_initialPrize),
            prize: _initialPrize,
            gameState: 0,
            winner: 0,
            player2Choice: 0
        });
        
        uint gameId = numberOfGames;
        listOfGames[gameId] = newGame;
        activeGamesIdList.push(gameId);
        WaitingForPlayerToJoin(gameId);
        numberOfGames++;
        return gameId;
    }

    function join(uint gameId, uint8 choice) public payable gameExists(gameId) atGameStateStarted(gameId) notByPlayer1(gameId)
    {
        Game storage game = listOfGames[gameId];
        
        // Check if player2 sent enough wei
        require((msg.value == game.prize));
        
        // Check if player2's choice is valid
        require(isValidChoiceValue(choice));
        
        game.player2 = msg.sender;
        
        // Put sent wei in to the deposit
        game.deposit += msg.value;
        
        // Store choice
        game.player2Choice = choice;
        
        // Change game state
        game.gameState = 1;
        
        PlayerJoinedEvent(gameId);
    }
    
    function reveal(uint gameId, uint8 _choice, string _salt) public gameExists(gameId) atGameStateNeedToReveal(gameId) onlyByPlayer1(gameId)
    {
        Game storage game = listOfGames[gameId];
        
        // verify that choice value is valid
        require(isValidChoiceValue(_choice));
        
        // verify user hashed choice and real choice
        require(sha256(_choice, _salt) == game.choiceHash);
        
        game.winner = chooseWinner(_choice, game.player2Choice);
        
        uint player1Share = 0;
        uint player2Share = 0;
        
        if (game.winner == 0) { // tie
            player2Share = game.prize; // gets back the wei
            player1Share = game.deposit - game.prize; // gets back the (deposit - player2's wei)
        } else if (game.winner == 1) {
            player1Share = game.deposit;
        } else {
            player1Share = game.deposit - (game.prize*2); // gets back the deposit - player2's wei
            player2Share = (game.prize*2); // player2 won player1's wei
        }

        game.deposit = 0;
        game.player1.transfer(player1Share);
        if (player2Share > 0) {
            game.player2.transfer(player2Share);
        }

        game.gameState = 2;
        deleteFromActiveGames(gameId);
        GameEndEvent(gameId);
    }
    
    function chooseWinner(uint8 _p1Choice, uint8 _p2Choice) internal pure returns (uint8)
    {
        if (_p1Choice == _p2Choice) { // tie
            return 0;
        } else if (_p1Choice == 1) { // rock
            if (_p2Choice == 2) { // paper beats rock
                return 2; // winner p2
            } else { // scissors is beaten by rock
                return 1;  // winner p1 
            }
        } else if (_p1Choice == 2) { // paper
            if (_p2Choice == 1) { // rock is beaten by paper
                return 1; // winner p1
            } else { // scissors beats paper
                return 2;  // winner p2 
            }
        } else { // scissors
            if (_p2Choice == 1) { // rock beats scissors
                return 2; // winner p1
            } else { // paper is beaten by scissors
                return 1;  // winner p1
            }
        }
    }
    
    function isValidChoiceValue(uint8 _choice) internal pure returns(bool)
    {
        return (_choice > 0 && _choice < 4);
    }
    
    // It won't be stored on the blockchain
    function getChoiceHash(uint8 _choice, string _salt) public pure returns(bytes32)
    {
        return sha256(_choice, _salt);
    }
    
    // Player1 choose not to reveal. It could be useful if player1 lost the salt.
    function noReveal(uint gameId) public atGameStateNeedToReveal(gameId) onlyByPlayer1(gameId)
    {
        Game storage game = listOfGames[gameId];

        uint player1Share = game.deposit - (game.prize*2);
        uint player2Share = game.prize*2;
        
        game.player2.transfer(player2Share);
        game.player1.transfer(player1Share);
        game.gameState = 2;
        deleteFromActiveGames(gameId);
        GameEndEvent(gameId);
    }
    
    // Give back player2's money
    function withdraw(uint gameId) public atGameStateNeedToReveal(gameId) onlyByPlayer2(gameId)
    {
        Game storage game = listOfGames[gameId];
        
        game.deposit -= game.prize;
        game.player2.transfer(game.prize);
        game.gameState = 0;
        delete(game.player2);
        WaitingForPlayerToJoin(gameId);
    }
    
    // No player2 ATM so player1 can delete the game.
    function deleteGame(uint gameId) public atGameStateStarted(gameId) onlyByPlayer1(gameId)
    {
        Game storage game = listOfGames[gameId];
        
        game.player1.transfer(game.deposit);
        game.gameState = 3; // deleted
        deleteFromActiveGames(gameId);
        DeletedEvent(gameId);
    }
    
    function getNumberOfActiveGames() public view returns(uint)
    {
        return activeGamesIdList.length;
    }
    
    function getActiveGameIdList() public view returns(uint[])
    {
        return activeGamesIdList;
    }
    
    function deleteFromActiveGames(uint gameId) internal
    {
        for(uint index = 0; index < activeGamesIdList.length; index++) {
            if (activeGamesIdList[index] == gameId) {
                delete activeGamesIdList[index];
                break;
            }
        }
        
        // https://ethereum.stackexchange.com/questions/1527/how-to-delete-an-element-at-a-certain-index-in-an-array
        if (index >= activeGamesIdList.length) return;

        for (uint j = index; j<activeGamesIdList.length-1; j++){
            activeGamesIdList[j] = activeGamesIdList[j+1];
        }
        delete activeGamesIdList[activeGamesIdList.length-1];
        activeGamesIdList.length--;
    }
    
    function getWinner(uint gameId) public view atGameStateEnd(gameId) returns(uint8)
    {
        Game storage game = listOfGames[gameId];
        return game.winner;
    }
}
