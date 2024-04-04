// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts@4.6.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.6.0/access/AccessControl.sol"; // Importar el contrato AccessControl para gestionar roles de acceso

contract Token is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); // Declaración de una constante que representa el rol de "Minter"

    constructor() ERC20("Carlos Castro Token", "CCT") {
        // Asignar roles al creador del contrato (msg.sender)
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); // Asignar el rol de administrador
        _setupRole(MINTER_ROLE, msg.sender); // Asignar el rol de minter
    }
    
    // Función para crear y asignar nuevos tokens a una dirección específica
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount); // Crear nuevos tokens y asignarlos a la dirección especificada
    }

    // Devuelve la cantidad de decimales que el token tiene
    function decimals() public pure override returns (uint8) {
        return 2; // El token tiene 2 decimales, por lo tanto, 1 token = 100 unidades mínimas
    }    
}
