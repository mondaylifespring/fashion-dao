# FashionDAO

A Decentralized Autonomous Organization (DAO) for fashion designers built on the Stacks blockchain.

## Overview

FashionDAO enables fashion designers to collaborate, make collective decisions, and fund projects through a decentralized governance system. Members hold governance tokens that grant voting rights proportional to their holdings.

## Features

- Governance token for voting rights
- Proposal creation and voting system
- Democratic decision-making for fashion initiatives
- Transparent governance process

## Smart Contract Functions

### Create Proposal
Allows members with sufficient tokens to create new proposals for the community to vote on.

### Vote
Enables token holders to vote on active proposals, with voting power proportional to token holdings.

### Finalize Proposal
Concludes the voting process and determines if a proposal is approved or rejected.

### Token Management
- Initialize tokens for founders
- Transfer tokens between members

## Getting Started

1. Clone this repository
2. Install [Clarinet](https://github.com/hirosystems/clarinet)
3. Run `clarinet check` to verify the contract
4. Deploy using Clarinet or the Stacks CLI