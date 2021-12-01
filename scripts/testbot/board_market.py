import matplotlib.pyplot as plt
import chain

class MarketBoard:
    
    AX: plt.Axes = None
    FIG: plt.Figure = None
    
    BlockID = -1
    T_BlockID: plt.Text = None
    T_PoolNames = []
    T_PoolSupplys = []
    T_PoolBorrows = []
    T_PoolReserve = []
    T_PoolSupplyAprs = []
    T_PoolBorrowAprs = []
    T_PoolUtility = []
    T_TotalSupply: plt.Text = None
    T_TotalBorrow: plt.Text = None
    T_TotalSupplier: plt.Text = None
    T_TotalBorrower: plt.Text = None

    def __init__(self, ax, fig):
        self.AX: plt.Axes = ax
        self.FIG: plt.Figure = fig
        self.AX.get_xaxis().set_visible(False)
        self.AX.get_yaxis().set_visible(False)

        self.CreateText()

    def CreateText(self):
        size_number = 7
        self.AX.text(0.00, 1.20, 'Market Board', horizontalalignment='left', size=9, color='green')
        self.AX.text(0.19, 1.01, 'Supply', horizontalalignment='right', size=9)
        self.AX.text(0.36, 1.01, 'Borrow', horizontalalignment='right', size=9)
        self.AX.text(0.48, 1.01, 'Reserve', horizontalalignment='right', size=9)
        self.AX.text(0.60, 1.01, 's-APR', horizontalalignment='right', size=9)
        self.AX.text(0.70, 1.01, 'b-APR', horizontalalignment='right', size=9)
        self.AX.text(0.90, 1.01, 'Utilization', horizontalalignment='right', size=9)
        self.T_BlockID: plt.Text = self.AX.text(1.0, 1.20, "0", horizontalalignment='right', size=9, color='green')
        for i in range(0, len(chain.PoolAddrs)):
            poolAddr = chain.PoolAddrs[i]
            poolName = chain.ConfigJson['PoolAddress'][poolAddr]['PoolName']
            idx = i+1
            self.T_PoolNames.append(        self.AX.text(-0.01, 1.0-0.1*idx, poolName, horizontalalignment='right', size=size_number, color='green') )
            self.T_PoolSupplys.append(      self.AX.text(0.19, 1.0-0.1*idx, "nil", horizontalalignment='right', size=size_number) )
            self.T_PoolBorrows.append(       self.AX.text(0.36, 1.0-0.1*idx, "nil", horizontalalignment='right', size=size_number) )
            self.T_PoolReserve.append(      self.AX.text(0.48, 1.0-0.1*idx, "nil", horizontalalignment='right', size=size_number) )
            self.T_PoolSupplyAprs.append(   self.AX.text(0.60, 1.0-0.1*idx, "nil", horizontalalignment='right', size=size_number) )
            self.T_PoolBorrowAprs.append(   self.AX.text(0.70, 1.0-0.1*idx, "nil", horizontalalignment='right', size=size_number) )
            self.T_PoolUtility.append(      self.AX.text(0.90, 1.0-0.1*idx, "nil", horizontalalignment='right', size=size_number) )
        self.T_TotalSupply = self.AX.text(0.19, -0.1, 'nil', horizontalalignment='right', size=size_number)
        self.T_TotalBorrow = self.AX.text(0.36, -0.1, 'nil', horizontalalignment='right', size=size_number)
        self.T_TotalSupplier = self.AX.text(0.19, 1.11, 'nil', horizontalalignment='right', size=size_number)
        self.T_TotalBorrower = self.AX.text(0.36, 1.11, 'nil', horizontalalignment='right', size=size_number)
        
        
        #
        self.UpdateUI()

    def UpdateUI(self):
        curBlockId = chain.BlockHeight
        if self.BlockID >= curBlockId: return
        self.BlockID = curBlockId
        
        self.T_BlockID.set_text('BlockID: '+str(self.BlockID))
        totalSupply = 0.0
        totalBorrow = 0.0
        totalSupplier = 0
        totalBorrower = 0
        for idx in range(0, len(chain.PoolAddrs)):
            poolAddr = chain.PoolAddrs[idx]
            poolInfo = chain.PoolInfos[poolAddr]
            poolSupply = float(poolInfo['marketSupplyScaled'])/1e18
            poolBorrow = float(poolInfo['marketBorrowScaled'])/1e18
            poolReserve = float(poolInfo['marketReserveScaled'])/1e18
            poolSupplyApr = float(poolInfo['marketSupplyApr'])/1e16
            poolBorrowApr = float(poolInfo['marketBorrowApr'])/1e16
            poolUtility = 0.0
            totalSupply = totalSupply + poolSupply * float(poolInfo['marketOraclePriceUsd'])/1e18
            totalBorrow = totalBorrow + poolBorrow * float(poolInfo['marketOraclePriceUsd'])/1e18
            totalSupplier = totalSupplier + int(poolInfo['marketSupplierCount'])
            totalBorrower = totalBorrower + int(poolInfo['marketBorrowerCount'])

            if float(poolInfo['marketSupplyScaled']) > 0:
                poolUtility = float(poolInfo['marketBorrowScaled'])/(float(poolInfo['marketSupplyScaled']) - float(poolInfo['marketReserveScaled']))*100
            
            self.T_PoolSupplys[idx].set_text(format(poolSupply, ',.4f'))
            self.T_PoolBorrows[idx].set_text(format(poolBorrow, ',.4f'))
            self.T_PoolReserve[idx].set_text(format(poolReserve, ',.4f'))
            self.T_PoolSupplyAprs[idx].set_text(format(poolSupplyApr, ',.4f')+'%')
            self.T_PoolBorrowAprs[idx].set_text(format(poolBorrowApr, ',.4f')+'%')
            self.T_PoolUtility[idx].set_text(format(poolUtility, ',.4f')+'%')
        self.T_TotalSupply.set_text(format(totalSupply, ',.4f'))
        self.T_TotalBorrow.set_text(format(totalBorrow, ',.4f'))
        self.T_TotalSupplier.set_text(format(totalSupplier, ',d')+' ers')
        self.T_TotalBorrower.set_text(format(totalBorrower, ',d')+' ers')
        