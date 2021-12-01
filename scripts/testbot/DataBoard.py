import matplotlib.pyplot as plt
from matplotlib.widgets import Button
import matplotlib.animation as Animation
import asyncio
import threading

from flow_py_sdk import flow_client, cadence, Script

from board_market import MarketBoard
from board_user import UserBoard
import chain
from AgentMgr import AgentMgr


defaultUserAddr = "0x045a1763c93006ca"

asyncio.run(chain.QueryAllMarkets())
asyncio.run(chain.UpdateAllMarketInfos())
asyncio.run(chain.UpdateCurUserInfo(defaultUserAddr))



#fig, ax = plt.subplots(figsize=(10,6))
fig, ax = plt.subplots(2,1,figsize=(8,5), gridspec_kw={'height_ratios': [1, 2]})

marketBoard = MarketBoard(ax[0], fig)
userBoard = UserBoard(ax[1], fig)

def OnClick_AddNewUser(event):
    userAddr = chain.CreateAccount()
    print('Add new user: ', userAddr)

def OnClick_QueryAllMarkets(event):
    pools = chain.QueryAllMarkets()
    print(pools)

def OnClick_QueryMarketInfo(event):
    info = chain.QueryMarketInfo()
    #print(info)
def OnClick_Deposit(event):
    chain.Deposit('FUSD', '0xe03daebed8ca0615', '2.0')

def OnClick_Update(event):
    print('update')
    marketBoard.UpdateUI()
    fig.canvas.draw_idle()

# buttons:
#addNewUserButtonPos = plt.axes([0.1, 0, 0.2, 0.075])
#addNewUserButton = Button(addNewUserButtonPos, 'Add New User')
#addNewUserButton.on_clicked(OnClick_AddNewUser)

#queryAllMarkets_Button = Button(plt.axes([0.1, 0.2, 0.2, 0.075]), 'All Markets')
#queryAllMarkets_Button.on_clicked(OnClick_QueryAllMarkets)

#Button_QueryAllMarkets = Button(plt.axes([0.1, 0.3, 0.2, 0.075]), 'Get Market Info')
#Button_QueryAllMarkets.on_clicked(OnClick_QueryMarketInfo)

#Button_Deposit = Button(plt.axes([0.1, 0.4, 0.2, 0.075]), 'Deposit')
#Button_Deposit.on_clicked(OnClick_Deposit)

#Button_Update = Button(plt.axes([0.1, 0.5, 0.2, 0.075]), 'Update')
#Button_Update.on_clicked(OnClick_Update)

# texts:
#Text_UserNum = plt.text(0, 2, 'Fake Users:')

lock = threading.Lock()

def show():
    plt.show()
    

async def UpdateUI():
    marketBoard.UpdateUI()
    userBoard.UpdateUI()
    fig.canvas.draw()
    #fig.canvas.flush_events()


async def UpdateData():
    while(True):
        await asyncio.sleep(1)
        
        await chain.QueryBlockInfo()
        await chain.UpdateAllMarketInfos()
        await chain.UpdateCurUserInfo(defaultUserAddr)

def thread_update_data_f():
    asyncio.run(UpdateData())

def thread_anim_update_ui(i):
    asyncio.run(UpdateUI())

def thread_agent_update():
    print('start agent mgr')
    agentMgr = AgentMgr()
    agentMgr.SetRandomAgentNum(1)
    asyncio.run(agentMgr.Run())


task_update_data = threading.Thread(target=thread_update_data_f)
task_update_data.start()
task_agent_update = threading.Thread(target=thread_agent_update)
#task_agent_update.start()


ani = Animation.FuncAnimation(fig, thread_anim_update_ui, interval=100)



show()


