pragma solidity ^0.4.18;

contract Powerball {
    struct Round {
        uint endTime;
        uint drawBlock;
        uint[6] winningNumbers;
        mapping(address => uint[6][]) tickets;
    }

    uint public constant TICKET_PRICE = 1 ether;
    uint public constant MAX_NUMBER = 69;
    uint public constant MAX_POWERBALL_NUMBER = 26;
    uint public constant ROUND_LENGTH = 1 minutes; 
    //ROUND_LENGTH can be 3 days but for testing now let just try 1 minutes
    // or 60 secs

    uint public round;
    mapping(uint => Round) public rounds;

    function Powerball () public {
        round = 1;
        rounds[round].endTime = now + ROUND_LENGTH;
    }

    function buy (uint[6][] numbers) payable public {
        require(numbers.length * TICKET_PRICE == msg.value);
    
        // Ensure the non-powerball numbers on each ticket are unique
        for (uint k=0; k < numbers.length; k++) {
            for (uint i=0; i < 4; i++) {
                for (uint j=i+1; j < 5; j++) {
                    require(numbers[k][i] != numbers[k][j]);
                }
            }
        }

        // Ensure the picked numbers are within the acceptable range
        for (i=0; i < numbers.length; i++) {
            for (j=0; j < 6; j++)
                require(numbers[i][j] > 0);
            for (j=0; j < 5; j++)
                require(numbers[i][j] <= MAX_NUMBER);
            require(numbers[i][5] <= MAX_POWERBALL_NUMBER);
        }

        // check for round expiry
        if (now > rounds[round].endTime) {
            rounds[round].drawBlock = block.number + 5;
            round += 1;
            rounds[round].endTime = now + ROUND_LENGTH;
        }

        for (i=0; i < numbers.length; i++)
            rounds[round].tickets[msg.sender].push(numbers[i]);
    }

    function drawNumbers (uint _round) public {
        uint drawBlock = rounds[_round].drawBlock;
        require(now > rounds[_round].endTime);
        require(block.number >= drawBlock);
        require(rounds[_round].winningNumbers[0] == 0);

        uint i = 0;
        uint seed = 0;
        while (i < 5) {
            bytes32 rand = keccak256(block.blockhash(drawBlock), seed);
            uint numberDraw = uint(rand) % MAX_NUMBER + 1;  

            // non-powerball numbers must be unique
            bool duplicate = false;
            for (uint j=0; j < i; j++) {
                if (numberDraw == rounds[_round].winningNumbers[j]) {
                    duplicate = true;
                    seed++;
                    break;
                }
            }
            if (duplicate)
                continue;

            rounds[_round].winningNumbers[i] = numberDraw;
            i++; seed++;
        }
        rand = keccak256(block.blockhash(drawBlock), seed);
        uint powerballDraw = uint(rand) % MAX_POWERBALL_NUMBER + 1;
        rounds[_round].winningNumbers[5] = powerballDraw;
    }

    function claim (uint _round) public {
        require(rounds[_round].tickets[msg.sender].length > 0);
        require(rounds[_round].winningNumbers[0] != 0);

        uint[6][] storage myNumbers = rounds[_round].tickets[msg.sender];
        uint[6] storage winningNumbers = rounds[_round].winningNumbers;

        uint payout = 0;
        for (uint i=0; i < myNumbers.length; i++) {
            uint numberMatches = 0;
            for (uint j=0; j < 5; j++) {
                for (uint k=0; k < 5; k++) {
                    if (myNumbers[i][j] == winningNumbers[k])
                        numberMatches += 1;
                }
            }
            bool powerballMatches = (myNumbers[i][5] == winningNumbers[5]);

            // win conditions
            if (numberMatches == 5 && powerballMatches) {
                payout = this.balance;
                break;
            }
            else if (numberMatches == 5)
                payout += 1000 ether;
            else if (numberMatches == 4 && powerballMatches)
                payout += 50 ether;
            else if (numberMatches == 4)
                payout += 1e17; // .1 ether
            else if (numberMatches == 3 && powerballMatches)
                payout += 1e17; // .1 ether
            else if (numberMatches == 3)
                payout += 7e15; // .007 ether
            else if (numberMatches == 2 && powerballMatches)
                payout += 7e15; // .007 ether
            else if (powerballMatches)
                payout += 4e15; // .004 ether
        }

        msg.sender.transfer(payout);
        delete rounds[_round].tickets[msg.sender];
    }

    function ticketsFor(uint _round, address user) public view 
      returns (uint[6][] tickets) {
        return rounds[_round].tickets[user];
    }

    function winningNumbersFor(uint _round) public view
      returns (uint[6] winningNumbers) {
        return rounds[_round].winningNumbers;
    }
}