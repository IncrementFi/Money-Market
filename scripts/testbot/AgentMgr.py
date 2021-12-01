import chain
import asyncio
from Agent import Agent, RandomAgent

class AgentMgr:
    _agentNum = 0
    _agentList_Random = []
    _agentNumLimit_Random = 0

    def __init__(self):
        self._agentNum = 0
        asyncio.run(chain.QueryAllMarkets())
        asyncio.run(chain.UpdateAllMarketInfos())

    async def CreateAgent_Random(self):
        agent = RandomAgent()
        self._agentList_Random.append(agent)
    
    def SetRandomAgentNum(self, num):
        self._agentNumLimit_Random = num

    async def Run(self):
        while(True):
            # random
            asyncio.create_task(chain.UpdateAllMarketInfos())
            
            if len(self._agentList_Random) < self._agentNumLimit_Random:
                asyncio.create_task(self.CreateAgent_Random())
            for agent in self._agentList_Random:
                asyncio.create_task(agent.Update())
            await asyncio.sleep(1.0)
    #def Update(self):
    #    while(True):
    #        for agent in self._agentList:
    #            agent.Update()
        