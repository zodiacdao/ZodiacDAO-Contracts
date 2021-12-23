require('@nomiclabs/hardhat-waffle')
require('@atixlabs/hardhat-time-n-mine')
require('@nomiclabs/hardhat-etherscan')

const fs = require('fs')
const dev = fs.readFileSync('.secret').toString().trim()
module.exports = {
  solidity: {
    compilers: [
      {
        version: '^0.8.0',
      },
      {
        version: '0.8.4',
      },
      {
        version: '0.7.5',
      },
      {
        version: '0.5.16', // for uniswap v2
      },
    ],
  },
  networks: {
    'mainnet': {
      url: 'https://bsc-dataseed.binance.org',
      chainId: 56,
      accounts: [dev],
      gasPrice: 20000000000,
      // gas: 20000000,
    },
    'testnet': {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      chainId: 97,
      accounts: [dev],
      gasPrice: 20000000000,
    },
    // hardhat: {
    //   gas: 'auto',
    // },
  },
  mocha: {
    timeout: 5 * 60 * 10000,
  },
}
