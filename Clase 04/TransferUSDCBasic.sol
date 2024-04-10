// SPDX-License-Identifier: MIT
// Declaración de la licencia bajo la cual se comparte este contrato.

pragma solidity 0.8.19;
// Declaración de la versión del compilador de Solidity que se utilizará.

// Deploy this contract on Fuji
// Este contrato se debe desplegar en la red de prueba Fuji.

// Importación de las interfaces y bibliotecas necesarias.
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol"; // Interfaz del router CCIP.
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol"; // Biblioteca del CCIP.
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol"; // Interfaz del token ERC20.
import {SafeERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/utils/SafeERC20.sol"; // Transferencia segura de ERC20.

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract TransferUSDCBasic {
    using SafeERC20 for IERC20; // Uso de la biblioteca SafeERC20 para transferencias seguras de tokens ERC20.

    // Tratamiento de errores personalizados.
    error NotEnoughBalanceForFees(uint256 currentBalance, uint256 calculatedFees); // Error lanzado cuando no hay suficiente saldo para pagar las tarifas.
    error NotEnoughBalanceUsdcForTransfer(uint256 currentBalance); // Error lanzado cuando no hay suficiente saldo USDC para la transferencia.
    error NothingToWithdraw(); // Error lanzado cuando no hay nada que retirar.

    // Variables de estado del contrato.
    address public owner; // Dirección del propietario del contrato.
    IRouterClient private immutable ccipRouter; // Instancia del router CCIP.
    IERC20 private immutable linkToken; // Instancia del token LINK.
    IERC20 private immutable usdcToken; // Instancia del token USDC.

    // Direcciones de contratos y selectores de cadena fuertemente tipificados.
    address ccipRouterAddress = 0xF694E193200268f9a4868e4Aa017A0118C9a8177; // Dirección del router CCIP en Fuji.
    address linkAddress = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846; // Dirección del token LINK en Fuji.
    address usdcAddress = 0x5425890298aed601595a70AB815c96711a31Bc65; // Dirección del token USDC en Fuji.
    uint64 destinationChainSelector = 16015286601757825753; // Selector de cadena de destino.

    // Evento para registrar transferencias de USDC.
    event UsdcTransferred(
        bytes32 messageId,
        uint64 destinationChainSelector,
        address receiver,
        uint256 amount,
        uint256 ccipFee
    );

    // Constructor del contrato.
    constructor() {
        owner = msg.sender; // Asigna al desplegador del contrato como propietario.
        ccipRouter = IRouterClient(ccipRouterAddress); // Inicializa la instancia del router CCIP.
        linkToken = IERC20(linkAddress); // Inicializa la instancia del token LINK.
        usdcToken = IERC20(usdcAddress); // Inicializa la instancia del token USDC.
    }

    // Función para transferir USDC a Sepolia.
    function transferUsdcToSepolia(
        address _receiver, // Dirección del receptor en la cadena de destino.
        uint256 _amount // Cantidad de USDC a transferir.
    )
        external
        returns (bytes32 messageId) // Devuelve el ID del mensaje CCIP.
    {
        // Crear una estructura de datos para el mensaje CCIP.
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: address(usdcToken),
            amount: _amount
        });
        tokenAmounts[0] = tokenAmount;

        // Crear el mensaje CCIP.
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: "",
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 0})
            ),
            feeToken: address(linkToken)
        });

        // Obtener la tarifa CCIP.
        uint256 ccipFee = ccipRouter.getFee(destinationChainSelector, message);

        // Verificar si hay suficiente saldo LINK para pagar la tarifa.
        if (ccipFee > linkToken.balanceOf(address(this)))
            revert NotEnoughBalanceForFees(linkToken.balanceOf(address(this)), ccipFee);
        linkToken.approve(address(ccipRouter), ccipFee);

        // Verificar si el remitente tiene suficiente saldo USDC para la transferencia.
        if (_amount > usdcToken.balanceOf(msg.sender))
            revert NotEnoughBalanceUsdcForTransfer(usdcToken.balanceOf(msg.sender));
        usdcToken.safeTransferFrom(msg.sender, address(this), _amount);
        usdcToken.approve(address(ccipRouter), _amount);

        // Enviar el mensaje CCIP.
        messageId = ccipRouter.ccipSend(destinationChainSelector, message);

        // Emitir el evento de transferencia de USDC.
        emit UsdcTransferred(
            messageId,
            destinationChainSelector,
            _receiver,
            _amount,
            ccipFee
        );
    }

    // Función para obtener la cantidad de USDC aprobada para gastar en este contrato.
    function allowanceUsdc() public view returns (uint256 usdcAmount) {
        usdcAmount = usdcToken.allowance(msg.sender, address(this));
    }

    // Función para obtener los saldos de tokens LINK y USDC de una cuenta.
    function balancesOf(address account) public view returns (uint256 linkBalance, uint256 usdcBalance) {
        linkBalance =  linkToken.balanceOf(account);
        usdcBalance = IERC20(usdcToken).balanceOf(account);
    }

    // Modificador para restringir el acceso a ciertas funciones solo al propietario del contrato.
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    // Función para que el propietario retire cualquier token ERC20 almacenado en el contrato.
    function withdrawToken(
        address _beneficiary, // Dirección a la que se enviarán los tokens retirados.
    address _token // Dirección del token ERC20 a retirar.
    ) public onlyOwner {
    uint256 amount = IERC20(_token).balanceOf(address(this)); // Obtener el saldo del token en el contrato.
    if (amount == 0) revert NothingToWithdraw(); // Verificar si hay algo que retirar.
    IERC20(_token).transfer(_beneficiary, amount); // Transferir el saldo del token al beneficiario.
    }
}
