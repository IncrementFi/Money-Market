import matplotlib.pyplot as plt
from matplotlib.widgets import Button, Slider, TextBox
from mpl_toolkits.axes_grid1.inset_locator import InsetPosition
import chain

class UserBoard:
    FIG: None
    AX: plt.Axes = None

    UserAddr = "0x045a1763c93006ca"

    BlockID = -1
    #T_BlockID: plt.Text = None
    T_UserAddr = None
    Input_UserAddr: TextBox = None
    

    T_PoolNames = []
    T_UserSupplys = []
    T_UseBorrows = []
    T_UseLocals = []
    T_UserUtilities = []
    Button_Faucets = []

    T_TotalSupply: plt.Text = None
    T_TotalBorrow: plt.Text = None
    
    def __init__(self, ax, fig):
        self.AX: plt.Axes = ax
        self.FIG: plt.Figure = fig
        self.AX.get_xaxis().set_visible(False)
        self.AX.get_yaxis().set_visible(False)

        self.CreateText()

    def UserAddrInput_Submit(self, expression):
        print(expression)

    def AddButton(self, coords, text, fontsize, color):
        ax = plt.axes([0, 0, 1, 1])
        ax.set_axes_locator( InsetPosition(self.AX, coords))
        
        button = Button(ax, text, color=color)
        button.label.set_fontsize(fontsize)
        return button

    def ClickCBMaker_Faucet(self, poolName):
        name = poolName
        def cb(event):
            chain.Faucet(name, self.UserAddr, "100.0")
        return cb 

    def CreateText(self):
        self.AX.text(0.00, 1.01, 'User Board', horizontalalignment='left', size=9, color='green')
        self.T_UserAddr = self.AX.text(0.15, 1.01, '0x01', horizontalalignment='left', size=7)

        # addr input
        #ax_inputAddr = plt.axes([0, 0, 1, 1])
        #ax_inputAddr.set_axes_locator( InsetPosition(self.AX, [0.8, 1.0, 0.2, 0.1]))
        #self.Input_UserAddr = TextBox( ax_inputAddr, 'User Addr:' )
        #self.Input_UserAddr.on_submit(self.UserAddrInput_Submit)
        
        #self.T_BlockID: plt.Text = self.AX.text(1.0, 1.1, "0", horizontalalignment='right', size=9)
        for i in range(0, len(chain.PoolAddrs)):
            poolAddr = chain.PoolAddrs[i]
            poolName = chain.ConfigJson['PoolAddress'][poolAddr]['PoolName']
            idx = i+1
            y = 1.0-0.1*idx
            self.T_PoolNames.append(        self.AX.text(-0.01, y, poolName, horizontalalignment='right', size=7, color='green') )
            self.T_UserSupplys.append(      self.AX.text(0.19, y, "nil", horizontalalignment='right', size=7) )
            self.T_UseBorrows.append(       self.AX.text(0.36, y, "nil", horizontalalignment='right', size=7) )
            self.T_UseLocals.append(        self.AX.text(0.52, y, "nil", horizontalalignment='right', size=7) )
            self.T_UserUtilities.append(    self.AX.text(0.90, y, "nil", horizontalalignment='right', size=7) )
            
            self.Button_Faucets.append( self.AddButton([0.55, y, 0.06, 0.05], 'Faucet', 7, 'w') )
            self.Button_Faucets[i].on_clicked(self.ClickCBMaker_Faucet(poolName))

        self.T_TotalSupply = self.AX.text(0.19, 0.01, 'nil', horizontalalignment='right', size=7)
        self.T_TotalBorrow = self.AX.text(0.36, 0.01, 'nil', horizontalalignment='right', size=7)
        
        
        #
        self.UpdateUI()

    def UpdateUI(self):
        curBlockId = chain.BlockHeight
        if self.BlockID >= curBlockId: return
        self.BlockID = curBlockId
        self.UserAddr = chain.CurUserAddr

        #self.T_BlockID.set_text('BlockID: '+str(self.BlockID))
        self.T_UserAddr.set_text(self.UserAddr)
        

        totalSupply = 0.0
        totalBorrow = 0.0
        for idx in range(0, len(chain.PoolAddrs)):
            poolAddr = chain.PoolAddrs[idx]
            poolInfo = chain.PoolInfos[poolAddr]
            userInfo = {}
            if chain.CurUserInfo.__contains__(poolAddr):
                userInfo = chain.CurUserInfo[poolAddr]

            userSupply = 0.0
            userBorrow = 0.0
            userLocal = userInfo['LocalVault']
            if userInfo != {} and userInfo.__contains__('userSupply'):
                userSupply = userInfo['userSupply']
                userBorrow = userInfo['userBorrow']

            poolUtility = 0.0
            totalSupply = totalSupply + userSupply * float(poolInfo['marketOraclePriceUsd'])/1e18
            totalBorrow = totalBorrow + userBorrow * float(poolInfo['marketOraclePriceUsd'])/1e18


            if float(userSupply) > 0:
                poolUtility = (userBorrow / userSupply)*100
            self.T_UserSupplys[idx].set_text(format(userSupply, ',.4f'))
            self.T_UseBorrows[idx].set_text(format(userBorrow, ',.4f'))
            self.T_UseLocals[idx].set_text(format(userLocal, ',.2f'))
            

            self.T_UserUtilities[idx].set_text(format(poolUtility, ',.4f')+'%')
        self.T_TotalSupply.set_text(format(totalSupply, ',.4f'))
        self.T_TotalBorrow.set_text(format(totalBorrow, ',.4f'))
        