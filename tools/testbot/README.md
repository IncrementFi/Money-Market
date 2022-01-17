### TestBot
Support simulation testing, stress testing and data visualization.

### How to Use
1. Create some users to interact with the lending pools randomly.
   After running emulator: `./scripts/multipool-deploy.sh`
  `python ./tools/testbot/UserRandomEmulator.py 10` to create 10 users.
2. Open data board for visualization.
  `python ./tools/testbot/DataBoard.py`

### Env
1. Upgrade python version to 3.9+.
   We recommend installing Anaconda (https://www.anaconda.com/products/individual)
    a. `conda create --name yourenv python=3.9` for your own testbot evn.
    b. then `conda activate yourenv` swith to your env
   or
    `brew install python@3.9` the version of python must be upgraded to ^3.9
2. Dependies:
  * `conda install matplotlib` if you use anaconda or `pip install matplotlib`
  * `pip install flow-py-sdk` to install flow python sdk
    for more info about flow python sdk: [docs](https://github.com/janezpodhostnik/flow-py-sdk/blob/master/docs/python_SDK_guide.md)

### TODO
Currently, only random agent is created for simulation.
In the future, rational agents can be made to simulate more realistic environment.
