AmazingEA ReadMe Instructions:-

Please check the following Thread on Forex Factory for News and Updates:-
http://www.forexfactory.com/showthread.php?t=6854

How do I make AmazingEA work?
1) Drop AmazingEA onto a Chart. Ensure there is a Smiley Face beside the name AmazingEA in the top-right corner of the chart.
2) Lookup the Time of a (preferably High Impact) News Event on Forex Factory Calendar
3) Convert the News Time to the equivalent time on your Brokers platform (unless UseBrokerTime is set to false).
4) Set NYear, NMonth, NDay, NHour, NMin and NSec to what the clock on Market Watch on MT4 will say when the News hits
5) The Default Settings are adequate for Testing on Demo
6) If the EA doesn't place orders check the 'Amazing EA Troubleshooter' Text File

PointsAway - Stop Order Distance in Points 
Distance above the current ask price and below the current bid price where the Stop Orders will be placed, unless CTCBN > 0.
If CTCBN > 0, the PointsAway distance will be added to the High and Low figure from CTCBN.  
If PointsAway is set to 0, the EA will use the broker's minimum distance for Pending Orders.

PointsGap - Orders are opened initially further away so they don't trigger accidentally and moved into position SecBAO seconds before News Time. This used to be hard-coded to 10000 but caused issues with 4-digit brokers. Please set to what is comfortable but please make it more than 1000 points. Set to 0 to disable.

ModifyGap - The EA modifies orders to keep the straddle positioned around current price, but each modification takes 1-2 seconds which is obviously much slower than price can move. ModifyGap sets the minimum distance that price has to move before generating an order modification. The idea is to stop the EA modifying orders for 0.00001 change in price, so it is ready for the larger price movements that might occur later. A value of 5 would mean EURUSD @ 1.32010 would need to be 1.32015 or 1.32005 before modifying. Set to 0 to disable. Maximum Value Allowed is 20.

TP - Take Profit amount in Points. 
When the order gets into profit this amount of Points, it will be closed automatically. Set to 0 to disable.

SL - Stop Loss amount in Points. Plus the Spread if you set AddSpreadToSL=true. Set to 0 to disable.

These following five parameters (NYear, NMonth, NDay, NHour, NMin and NSec) are the broker's date and time, not the PC's date and time (unless UseBrokerTime is set to false).

NYear - News Year. 
If NYear, NMonth and NDay are all set to 0, then the EA will trade Monday to Friday day at NHour, NMin and NSec. Brokers do not allow Pending Orders to be entered over weekends.

NMonth - News Month. 
See Note for NYear.

NDay - News Day. 
See Note for NYear.

NHour - News Hour.

NMin - News Minute.

NSec - News Seconds.

CTCBN - Candles To Check Before News.
For determining High & Lows , when it is 1 it checks the current candle, when it is 2 it checks the current candle and the previous one. If CTCBN = 0, PointsAway is used from Bid price for Sells and Ask price for Buys. If CTCBN > 0, PointsAway is used from the Low for Sells and High for Buys, where the Low and High are the lowest and highest price reached within the number of candles specified. Set to 1 for default, 0 to disable. 

SecBPO - Seconds Before Pending Orders
How many seconds before News Time should the EA place Pending Orders. There is a trade-off here. If set too high, the pending orders may go live early. So, set this as low as possible. But if it's too low, there may not be enough time for MT4 to open the orders. Running 6 charts on 3 brokers, expect to set this to at least 60. Most traders will find the default setting of 20 adequate. This is not going to happen at the exact second specified, because EA code is executed only when a tick signal comes from the broker, but around the news price movements are frequent. If you set SecBAO, a special technique will be employed where the orders are opened 1000 points away + PointsAway setting from current price, which allows you to open orders earlier but safely. See SecBAO setting. 

SecBMO - Seconds Before Modify Orders
Once the orders are placed, the EA will follow the price movement and modify orders accordingly so that they are always the correct distance away from the current price. With some volatile news this can be quite often, so if that creates a problem with your broker you can set this to half of the value you put for SecBPO, if you put this to be equal as SecBPO than EA will not modify the orders at all. If set to 0, then the EA will keep modifying right up to the news time. Default Setting is 0.

SecBAO - Seconds Before Adjacent Orders
If you set SecBAO, a special technique will be employed where the orders are opened 'PointsGap' points away + PointsAway setting from current price, which allows you to open orders earlier but safely. If PointsGap is 0 (or SecBAO=SecBPO or SecBAO=0), then SecBAO is ignored. When the time reaches SecBAO seconds before the news, the orders will be moved into place. If you set this to the same value as SecBPO, the code is ignored and the EA just opens the orders at the normal distance and doesn't move them. On Demo, you may find the orders aren't moved because there aren't enough price ticks generated. In this case try setting SecBAO higher than 10. On Live, during news you may be able to set as low as 3 seconds. Default Setting is 5. Set to 0 to disable.

STWAN - Seconds To Wait After News
This is the timer to cancel all the orders that did not get triggered. Default Setting is 5. 

OCO - Order Cancel Other
If this is set to true, when your order gets hit the corresponding opposite order will be cancelled but without waiting for STWAN time. This is only effective after News Time, not before.

BEPoints - Break Even Points
Points In profit which EA will Move SL to Break Even + BEOffset; a nice way to lock in some profit. If you leave it at 0 nothing will happen.

BEOffset - Break Even Offset
Number of points to move beyond Break Even (allows to cover Broker Commissions etc.) Set to 0 to disable.

TrailPoints - Trailing Stop
Enter the amount of Points you want to trail by. If you set this to 20 points, the EA will maintain a distance of 20 points behind current price. Setting to 0 disables trailing stops.

TrailOffset - Trailing Stop Offset
Enter the amount of Points after which you want Trailing to start. Setting to 0 enables Trailing to start as soon as the trade is in profit. If you set this to 150, and TrailPoints is 50, then after 200 points in profit, your Stop will jump to 150 points and maintain a distance 5 points behind current price as long as price keeps moving in the correct direction of course.

TrailImmediate - Start Trailing Immediately
If set to true, the EA will start moving the Stop Loss even when the trade is not in profit. Only do this on brokers where the spread is kept low. If the broker is prone to spike the spread, then this will cause early stop outs. The advantage of using this is that if the news comes out as expected and the trade moves a little bit in your favour, but then reverses, you may capture a few pips.

MM - Money Management
If you set MM to true, the EA will automatically determine the number of lots for your orders, according to the risk you are willing to take

RiskPercent - The risk you are willing to take on any single order.
Risk Percentage is worked out as a percentage of the available margin. The calculation now uses 2 decimal places instead of 1, which will allow the trading of micro-lots. The calculation currently now takes into account Stop Loss distance. If you set MaxSpread, then the Risk calculation will be based on Stop Loss distance + MaxSpread. However, please don't assume that is your maximum risk because brokers can and will slip stop-loss orders.

Lots - Number of Lots for your orders
If you set MM to false, than you have to tell the EA how many lots to use for the orders; so if you put here 1, every order will be placed with 1 lot

MaxSpread - The maximum spread in points you wish to allow for your orders. 
If the spread grows higher than this level, the EA deletes any Pending Orders and will not open new ones until the Spread lowers below this Setting for at least 5 seconds. Don't worry if your orders go live just prior to deletion, the EA will still manage them. Set to 0 to disable.

AddSpreadToSL - Whether to include the spread in Stop Loss settings
If you set AddSpreadToSL to True, then the EA will automatically add the spread to the Stop Loss, so 10 pips will actually become 10 pips plus the spread which could be 20 pips during NFP. If you set AddSpreadToSL to False, the EA will set hard stops based on this setting only, which is good for knowing your max risk etc. You can also use MaxSpread to limit the stop level required for the Spread.

SlipCheck - Whether to perform Stop Loss Reset and Slippage Check
If you set SlipCheck to true, the EA will check for Slippage and reset Stop Losses and Take Profit levels. If you set it to false, the EA will behave more like the original (around v1.2.2) and only run the Break Even and Trailing Stop routines, not the Slippage Check or Stop Loss Reset routines.

MaxSlippage - The maximum slippage in points you wish to allow for your orders.
Unfortunately, this value cannot prevent orders going live and being slipped in the first place. But if the slippage on an 'opened' order exceeds the value set here, the trade will have it's stop loss set to the minimum distance allowed by the broker. If the trade goes against you, it will be closed quickly. If it doesn't, then there is a chance to recoup some losses.
This parameter requires Take Profit to be set. If you don't want to use Take Profit, then set TP to a very high value.

AllowBuys - Whether Long Orders are allowed or not.
Default is true. Set to false to disable Long Orders.

AllowSells - Whether Short Orders are allowed or not.
Default is true. Set to false to disable Short Orders.

UseBrokerTime - UseBrokerTime=true is how the EA used to work, UseBrokerTime=false uses the Local PC Time instead. If you use the Local PC time, I highly recommend using a program like 'Net Time' from http://www.timesynctool.com to ensure your PC clock is accurate. I also recommend you install MT4Ticker (https://www.fx1.net/wiki/pmwiki.php/MT4Ticker/MT4Ticker) and set the Tick Speed to 500ms. This will get the EA to run every 500ms and will make the clock and timers work more accurately.

DeleteOnShutdown - Whether to remove orders when Shutting Down the EA or Changing Timeframe on the Chart.
Default is true. Set to false to keep your orders when changing Timeframe on the Chart. In this case, any leftover orders must be manually removed.

TradeLog - EA will use this to create a name for the log file. If you set this to 'AmazingEA', and use it on an EURUSD chart, the Logfile will be called 'AmazingEA-Log-EURUSD-2015-02-24.log'. A TickFile called 'AmazingEA-Ticks-EURUSD-2015-02-24.csv' will also be created containing Bid and Ask Prices and Spread Data. You will find these files in the experts\files folder of your MT4 platform, with detailed explanations what took place while EA was running.

A new logging function has been added to capture EA settings in the Comment field of the trade. This is very useful because you can instantly see what settings were used on a trade in 'MyFXBook' for example without hunting through logfiles.

Because the Comment field is quite small (max length 32 characters), I have had to abbreviate everything and skip settings that can be worked out from the trade itself. 
Example: P100T1000S100C1P20A5M0W5O0B50T0 - This means PointsAway=100, TP=1000, SL=100, CTCBN=1, SecBPO=15, SecBAO=5, SecBMO=0, STWAN=5, OCO=0, BE=50, Trailing=0

So, when you attach AmazingEA to your chart and set it the way you want, it will monitor what is happening, place buy and sell orders, modify them, move hard stops to break even, trail stop them ... and do the best it can to help you make some $$$$$. Test it on demo before you go live, to make yourself comfortable with it and to see how it will interact with your broker.

A new safety function has been added to delete any pending orders when the EA is removed from the chart. However, if you disable the EA, and you have pending orders already placed, the EA will no longer adjust the straddle, with the consequence that your pending orders may go live before news time. The safest way to disable the EA is to remove it from the chart. Another quick way is to disable EAs and change the time-frame. When setting up, one should always save the settings used in a .set file - this makes it easier to setup again on the same or another broker. 

Good Luck !
