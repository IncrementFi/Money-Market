import chain
import asyncio
from Agent import Agent, RandomAgent, BorrowAgent, DepositAgent

class AgentMgr:
    _agentNum = 0
    _agentList_Random = []
    _agentList_Borrow = []
    _agentList_Deposit = []
    _agentNumLimit_Random = 0
    _agentNumLimit_Borrow = 0
    _agentNumLimit_Deposit = 0

    def __init__(self):
        self._agentNum = 0
        asyncio.run(chain.QueryAllMarkets())
        asyncio.run(chain.UpdateAllMarketInfos())

    async def CreateAgent_Random(self):
        agent = RandomAgent()
        self._agentList_Random.append(agent)
    async def CreateAgent_Borrow(self):
        agent = BorrowAgent()
        self._agentList_Borrow.append(agent)
    async def CreateAgent_Deposit(self):
        agent = DepositAgent()
        self._agentList_Deposit.append(agent)
    
    def SetRandomAgentNum(self, num):
        self._agentNumLimit_Random = num
    def SetBorrowAgentNum(self, num):
        self._agentNumLimit_Borrow = num
    def SetDepositAgentNum(self, num):
        self._agentNumLimit_Deposit = num

    async def Run(self):
        while(True):
            # random
            asyncio.create_task(chain.UpdateAllMarketInfos())
            
            if len(self._agentList_Random) < self._agentNumLimit_Random:
                asyncio.create_task(self.CreateAgent_Random())
            if len(self._agentList_Borrow) < self._agentNumLimit_Borrow:
                asyncio.create_task(self.CreateAgent_Borrow())
            if len(self._agentList_Deposit) < self._agentNumLimit_Deposit:
                asyncio.create_task(self.CreateAgent_Deposit())

            for agent in self._agentList_Random:
                asyncio.create_task(agent.Update())
            for agent in self._agentList_Borrow:
                asyncio.create_task(agent.Update())
            for agent in self._agentList_Deposit:
                asyncio.create_task(agent.Update())
                #asyncio.run(agent.Update())

            await asyncio.sleep(1.0)
    #def Update(self):
    #    while(True):
    #        for agent in self._agentList:
    #            agent.Update()
        