# Project 2
### Gossip Simulator

A simulator for gossip algorithm written in elixir. There are two algorithms implemented in this project. One for spreading epidemic and one for calculating average. Many topologies have been implemented in order to simulate the spreading of epidemic. The systems converges based on a condition for a algorithm. In case of spreading epidemic we have use the push-pull model of gossip with counter. In case of computing aggregate we use push-pull as well.

#### Team members
1. Pulkit Tripathi
2. Akash Shingte

#### Prerequisites
* [Elixir](https://elixir-lang.org/install.html)

#### Installing
* Install dependecies
```elixir
mix deps.get
````
* Compile the source
```elixir
mix compile
```
* Run the proj2.exs
```bash
mix run --no-halt proj2.exs <nodes> <topology> <algorithm>
```

Here,
```<nodes>``` is a ```integer``` between 1 and 100
```<topology>``` is a ```string``` which is one of 
- ```fulll```
- ```3D```
- ```line```
- ```imp2D```
- ```torrus```
- ```rand2D```

 ```<algorithm>``` is a ```string``` which is one of
- ```gossip```
- ```pushsum```

For example for **gossip algorithm** with **100 nodes** in **full topology**
```bash
mix run --no-halt proj2.exs 100 full gossip
```
### Running tests
```bash
mix test --trace --exclude pending
```
#### What is working?

Following implementations are working
1. Gossip algorithm for -  
    * Full topology
    * Line topology
    * Imperfect line topology
    * Torrus topology
    * 3d topology
2. Pushsum algorithm for
    * Full topology
    * Line topology
    * Imperfect line topology
    * Torrus topology
    * 3d topology

Following implementations have bugs to be sorted out in future release
1. Gossip algorithm
    - rand 2d topology
2. Pushsum algorithm
    - rand 2d topology

#### How we measured convergence time?

We used a GenServer monitor which will collect convergence events. Once convergence event for all nodes have reached the time is reported as the convergence time. 

