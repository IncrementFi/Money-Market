import asyncio
import threading
import sys
import chain
from AgentMgr import AgentMgr

userNum = 5
if len(sys.argv) >= 2:
    userNum = int(sys.argv[1])

asyncio.run(chain.QueryAllMarkets())
asyncio.run(chain.UpdateAllMarketInfos())


lock = threading.Lock()

def thread_agent_update():
    print('start agent manager')
    agentMgr = AgentMgr()
    agentMgr.SetDepositAgentNum(userNum)
    asyncio.run(agentMgr.Run())

#task_agent_update = threading.Thread(target=thread_agent_update)
#task_agent_update.start()

thread_agent_update()