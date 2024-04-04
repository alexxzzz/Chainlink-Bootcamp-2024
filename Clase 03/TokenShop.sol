// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// Importar la interfaz del Aggregator de Chainlink
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// Definir una interfaz para el token
interface TokenInterface {
    function mint(address account, uint256 amount) external;
}

contract TokenShop {
    
    AggregatorV3Interface internal priceFeed; // Interfaz para obtener el precio de ETH/USD
    TokenInterface public minter; // Interfaz para interactuar con el contrato del token
    uint256 public tokenPrice = 100; // Precio de 1 token en centavos de dólar (USD), con 2 decimales
    address public owner; // Dirección del propietario del contrato
    

    // Constructor que toma la dirección del contrato del token
    constructor(address tokenAddress) {
        minter = TokenInterface(tokenAddress); // Inicializar la interfaz del token
        /**
        * Network: Sepolia
        * Aggregator: ETH/USD
        * Address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        */
        // Asignar la dirección del propietario como el que despliega el contrato
        owner = msg.sender;
        // Dirección del Aggregator de Chainlink para obtener el precio de ETH/USD en la red Sepolia
        priceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    }

    /**
    * Devuelve el precio más reciente de ETH/USD del Aggregator de Chainlink
    */
    function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return price;
    }

    // Función para calcular la cantidad de tokens que se recibirán por una cantidad de ETH
    function tokenAmount(uint256 amountETH) public view returns (uint256) {
        uint256 ethUsd = uint256(getChainlinkDataFeedLatestAnswer()); // Precio de 1 ETH en centavos de dólar (USD)
        // Convertir la cantidad de ETH a su equivalente en USD
        uint256 amountUSD = amountETH * ethUsd / 10**18; // ETH tiene 18 decimales
        // Calcular la cantidad de tokens basada en el precio actual del token
        uint256 amountToken = amountUSD / tokenPrice / 10**(8/2); // El token tiene 2 decimales
        return amountToken;
    } 

    // Función que permite a los usuarios comprar tokens enviando ETH al contrato
    receive() external payable {
        uint256 amountToken = tokenAmount(msg.value); // Calcular la cantidad de tokens a recibir
        minter.mint(msg.sender, amountToken); // Emitir los tokens al comprador
    }

    // Modificador para restringir ciertas funciones solo al propietario
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // Función para que el propietario pueda retirar ETH del contrato
    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
}
