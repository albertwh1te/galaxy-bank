
# Galaxy Bank

The Galaxy Bank Protocol stands as a robust system, allowing users the capability to mint Galaxy USD (GUSD) tokens upon providing suitable collateral. GUSD, a stablecoin meticulously pegged to the US dollar, benefits from the backing of a broad spectrum of cryptographic assets. This foundational support guarantees its unwavering stability and unwarranted value preservation. Notably, Galaxy USD consistently maintains an over-collateralized stance, further reinforcing its credibility.

## Repository Structure


```
├── README.md
├── foundry.toml
├── lib
│   ├── forge-std
│   └── solmate                 (gas optimized building blocks for smart contract)
├── script
│   └── DeployGalaxyBank.s.sol  
├── slither.config.json         (config file for static analyzer )
├── src
│   ├── GalaxyBank.sol          
│   ├── GalaxyUSD.sol
│   ├── SafeChainlinkLib.sol    (safe check for Chainlink)
│   └── interfaces              
└── test
    ├── GalaxyBank.t.sol        
    ├── GalaxyUSD.t.sol
    ├── invariant                (folder for  invariant test)
    └── mocks

```

## Test

- run all test
```Bash
forge test
```

- run unit test
```Bash
forge test --match-contract Galaxy
```

- invariant test
```bash
forge test --match-contract Invariant
```

