//+------------------------------------------------------------------+
//|        AmazingEA.mq5 MetaTrader 5 Version 5.20 By Alan Prothero  |
//|               See "AmazingEA Change Log.txt" for Update History  |
//+------------------------------------------------------------------+
#property copyright "Alan Prothero"
#property link      "http://www.forexfactory.com/showthread.php?t=6854"
#property version   "5.20"

#property description "AmazingEA is a News Trading Straddle Program."
#property description "It places Buy and Sell Orders Above and Below the Current Price"
#property description "and modifies them until the time of a News Event."
#property description "Once Orders are Live it will Cancel the Opposing Order if required"
#property description "and Trail or Move Stop Losses to Break Even."
#property description "BEWARE! Some Brokers gap Prices and fill far away from the Requested Price."

#property description "Please check the following Thread on Forex Factory for News and Updates:-"
#property description "http://www.forexfactory.com/showthread.php?t=6854"

input int PointsAway=80; // PointsAway, distance to orders.
input int PointsGap=2000; // PointsGap, extra initial distance to orders.
input int ModifyGap=10; // ModifyGap, price change needed to modify.
input int TP=1000; // TP, Take Profit (0=disable).
input int SL=100; // SL, Stop Loss (0=disable).
input int NYear=0;  // NYear, News Year (0=trade EA every day).
input int NMonth=0;  // NMonth, News Month (0=trade EA every day).
input int NDay=0;  // NDay, News Day (0=trade EA every day).
input int NHour=0; // NHour, News Hour.
input int NMin=0;  // NMin, News Minute.
input int NSec=0;  // NSec, News Second.
input int CTCBN=0; // CTCBN, Candles To Check Before News (0=disable).
input int SecBPO=20; // SecBPO, Seconds Before Pending Orders.
input int SecBAO=5; // SecBAO, Seconds Before Adjacent Orders.
input int SecBMO=0; // SecBMO, Seconds Before Modifying Orders.
input int STWAN=5; // STWAN, Seconds To Wait After News (0=disable).
input bool OCO=true; // OCO, Order Cancel Other.
input int BEPoints=0; // BEPoints, Break Even Points (0=disable).
input int BEOffset=0; // BEOffset, Break Even Offset (0=disable).
input int TrailPoints=0; // TrailPoints, Trailing Stop Points (0=disable).
input int TrailOffset=0; // TrailOffset, Trailing Stop Offset (0=disable).
input bool TrailImmediate=false; // TrailImmediate, trail immediately when true.
input bool MM=false; // MM, Money Management, if true uses RiskPercent.
input double RiskPercent=2.5; // RiskPercent, overrides Lots.
input double Lots=0.1; // Lots, Lot Size ()if not MM and RiskPercent).
input int MaxSpread=60; // MaxSpread, cancels orders if spread exceeds (0=disable).
input bool AddSpreadToSL=true; // AddSpreadToSL, adds spread to Stop Loss.
input bool SlipCheck=false; // SlipCheck, checks for slippage and resets Stop Loss.
input int MaxSlippage=200; // MaxSlippage, close early if exceeded (0=disable).
input bool AllowBuys=true; // AllowBuys, switch on Buy Trades.
input bool AllowSells=true; // AllowSells, switch on Sell Trades.
input bool UseBrokerTime=true; // UseBrokerTime, false uses PC Clock.
input bool DeleteOnShutdown=true; // DeleteOnShutdown, false keeps Orders.
input string TradeLog = "AmazingEA"; // TradeLog, Log is created in Experts/Files.
double h,l,ho,lo,hso,lso,htp,ltp,sp;
int Magic,MinStopLevel,_PointsAway,_ModifyGap,_TP,_SL,_TrailPoints,_BEPoints,_OCO;
string TradeComment,logfile,tickfile ;

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>

//+------------------------------------------------------------------+
//| Main Position Class                                              |
//+------------------------------------------------------------------+
CTrade *Trade;
CPositionInfo PositionInfo;
COrderInfo OrderInfo;

//+------------------------------------------------------------------+
//| Calculate Position Size Depending on Money Management            |
//+------------------------------------------------------------------+
double LotsOptimized()
{
	double lot=Lots;	//---- select lot size
	double minlot = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
	double lotstep = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
	if (MM) { // if using Money Management
		if (SL!=0) { // if SL is set, take into account Stop Loss Distance
			double risk;
			double ppp = SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_VALUE); //PricePerPoint

			if (AddSpreadToSL) { // if AddSpreadToSL is true, add in MaxSpread
				risk=(AccountInfoDouble(ACCOUNT_FREEMARGIN)*RiskPercent/100)/(SL+MaxSpread);
			}
			else // if AddSpreadToSL is false, just use SL
			{
				risk=(AccountInfoDouble(ACCOUNT_FREEMARGIN)*RiskPercent/100)/SL;
			}
			lot = risk/ppp;
		}   
		else {
			Write(logfile,"SL has to be Set to use Money Management");
		}
	}
	lot = MathFloor(lot/lotstep)*lotstep; // Ensure using correct multiples of lots
	if (lot < minlot) { 
		lot = minlot;
	}
	return(lot);
} 

//+------------------------------------------------------------------+
//| Add Leading Zero to even out Data Displays                       |
//+------------------------------------------------------------------+
string AddLeadingZero(int number, int digits)
{
	// add leading zeros that the resulting string has 'digits' length.
	string result;
	result = DoubleToString(number, 0);
	while(StringLen(result)<digits) result = "0"+result;
	return(result);
}

//+------------------------------------------------------------------+
//| Check for Pending Stop Orders and Open Positions                 |
//+------------------------------------------------------------------+
int CheckOrdersCondition()
{
	int result = 0;

	//First deal with the Orders
	for (int i=OrdersTotal()-1; i>=0; i--)
	{
		if (OrderSelect(OrderGetTicket(i))) 
		{
			if ((OrderInfo.Symbol() == _Symbol) && (OrderInfo.Magic() == Magic) && (OrderInfo.OrderType() == ORDER_TYPE_BUY_STOP))
			{
				result = result + 10;
			}
			else if ((OrderInfo.Symbol() == _Symbol) && (OrderInfo.Magic() == Magic) && (OrderInfo.OrderType() == ORDER_TYPE_SELL_STOP))
			{
				result = result + 1;
			}
		}
	}

	//Now deal with the positions
	if (PositionInfo.Select(_Symbol) && (PositionInfo.Magic() == Magic))
	{
		if (PositionInfo.PositionType() == POSITION_TYPE_BUY)
		{
			result = result + 1000;
		}
		else if (PositionInfo.PositionType() == POSITION_TYPE_SELL)
		{ 
			result = result + 100;
		}
	}
	return(result); // 0 means there are no orders/positions
}
//   Result Pattern
//    1    1    1    1
//    |    |    |    |
//    |    |    |    -------- Sell Stop Order
//    |    |    --------Buy Stop Order
//    |    --------Sell Position
//    --------Buy Position



//+------------------------------------------------------------------+
//| Open Buy Stop Pending Order                                      |
//+------------------------------------------------------------------+
void OpenBuyStop()
{
	ulong ticket, tries;
	tries = 0;
	if (!GlobalVariableCheck("InTrade")) {
		while (tries<3)
		{
			GlobalVariableSet("InTrade", TimeCurrent());  // Set Lock Indicator (Semaphore Set)
			Trade.OrderOpen(_Symbol,ORDER_TYPE_BUY_STOP,LotsOptimized(),0,ho,hso,htp,0,0,TradeComment);
			ticket = Trade.ResultOrder(); // Get ticket
			Write(logfile,"OpenBuyStop, OrderSend Executed, @ "+DoubleToString(ho,_Digits)+" SL @ "+DoubleToString(hso,_Digits)+" TP @ "+DoubleToString(htp,_Digits)+" ticket="+IntegerToString(ticket));
			GlobalVariableDel("InTrade");   // Clear Lock Indicator (Semaphore Del)
			if (ticket<=0) {
				Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
				tries++;
			} else tries = 3;
		}
	}
}

//+------------------------------------------------------------------+
//| Open Sell Stop Pending Order                                     |
//+------------------------------------------------------------------+
void OpenSellStop()
{
	ulong ticket, tries;
	tries = 0;
	if (!GlobalVariableCheck("InTrade")) {
		while (tries<3)
		{
			GlobalVariableSet("InTrade", TimeCurrent());  // Set Lock Indicator (Semaphore Set)
			Trade.OrderOpen(_Symbol,ORDER_TYPE_SELL_STOP,LotsOptimized(),0,lo,lso,ltp,0,0,TradeComment);
			ticket = Trade.ResultOrder(); // Get ticket
			Write(logfile,"OpenSellStop, OrderSend Executed, @ "+DoubleToString(lo,_Digits)+" SL @ "+DoubleToString(lso,_Digits)+" TP @ "+DoubleToString(ltp,_Digits)+" ticket="+IntegerToString(ticket));
			GlobalVariableDel("InTrade");   // Clear Lock Indicator (Semaphore Del)
			if (ticket<=0) {
				Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
				tries++;
			} else tries = 3;
		}
	}
}


//+------------------------------------------------------------------+
//| Adjust Pending Orders to New High/Low Prices                     |
//+------------------------------------------------------------------+
void DoModify()
{
	double hbp,lbp,hsp,lsp;
	for (int i=OrdersTotal()-1; i>=0; i--) {
		ulong ticket = OrderGetTicket(i);
		if (OrderSelect(ticket)) {
			if ((OrderInfo.Symbol()==_Symbol) && (OrderInfo.Magic()==Magic) && (OrderInfo.OrderType()==ORDER_TYPE_BUY_STOP)) {
				hbp=OrderInfo.PriceOpen()+(_ModifyGap*_Point);
				lbp=OrderInfo.PriceOpen()-(_ModifyGap*_Point);
				if (NormalizeDouble(ho,_Digits)>NormalizeDouble(hbp,_Digits) || NormalizeDouble(ho,_Digits)<NormalizeDouble(lbp,_Digits)) {
					Write(logfile,"Buy Stop was @ "+DoubleToString(OrderInfo.PriceOpen(),_Digits)+", changed to "+DoubleToString(ho,_Digits));
					if ( ! Trade.OrderModify(ticket,ho,hso,htp,0,0)) {
						Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
					}
				}
			}
			else if ((OrderInfo.Symbol() == _Symbol) && (OrderInfo.Magic()==Magic) && (OrderInfo.OrderType() == ORDER_TYPE_SELL_STOP)) {
				hsp=OrderInfo.PriceOpen()+(_ModifyGap*_Point);
				lsp=OrderInfo.PriceOpen()-(_ModifyGap*_Point);
				if (NormalizeDouble(lo,_Digits)>NormalizeDouble(hsp,_Digits) || NormalizeDouble(lo,_Digits)<NormalizeDouble(lsp,_Digits)) {
					Write(logfile,"Sell Stop was @ "+DoubleToString(OrderInfo.PriceOpen(),_Digits)+", changed to "+DoubleToString(lo,_Digits));
					if ( ! Trade.OrderModify(ticket,lo,lso,ltp,0,0)) {
						Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
					}
				}
			}
		}
	}
}

//+------------------------------------------------------------------+
//| Work Out Slippage and Close if Max Slippage Exceeded             |
//+------------------------------------------------------------------+
void DoSlip()
{
	double Ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
	double Bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
	double slippage;
	double osl,sl,be,of,otp,tp;
	if (PositionInfo.Select(_Symbol) && (PositionInfo.Magic()==Magic)) { // only look if mygrid and symbol...
		otp=PositionInfo.TakeProfit();
		osl=PositionInfo.StopLoss();
		if (PositionInfo.PositionType() == POSITION_TYPE_BUY) {
			be=PositionInfo.PriceOpen()+((BEPoints+BEOffset)*_Point);
			of=PositionInfo.PriceOpen()+(BEOffset*_Point);
			tp=PositionInfo.PriceOpen()+(TP*_Point);
			slippage=NormalizeDouble((tp - otp)/_Point,0); // slippage is how far Take Profit is out by
			if (MaxSlippage!=0 && slippage>MaxSlippage) // if slippage exceeds maxslippage
			{
				if (AddSpreadToSL) { // set MinStop
					sl=PositionInfo.PriceOpen()-sp-(MinStopLevel*_Point);
				}
				else {
					sl=PositionInfo.PriceOpen()-(MinStopLevel*_Point);
				}
				Write(logfile,"Slippage of Buy Order was "+DoubleToString(slippage,0)+", exceeded MaxSlippage of "+DoubleToString(MaxSlippage)+", setting MinStop to "+DoubleToString(sl,_Digits));
			}
			else // if slippage does not exceed maxslippage
			{
				if (slippage>0) { //output slippage to log
					Write(logfile,"Slippage of Buy Order was "+DoubleToString(slippage,0));
				}
				if (AddSpreadToSL) { // set normal stop
					sl=PositionInfo.PriceOpen()-sp-(SL*_Point);
				}
				else {
					sl=PositionInfo.PriceOpen()-(SL*_Point);
				}
			}
			if (Bid>tp)
			// if bid higher than buy take profit level, close
			{
				Write(logfile,"Take Profit of Buy Order Hit at "+DoubleToString(tp,_Digits)+", Closing at "+DoubleToString(Bid,_Digits));
				if ( ! Trade.PositionClose(_Symbol,0)) {
					Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
				}
			}
			if (BEPoints==0 || Bid<be) {
				if (osl<sl) 
				// is bid lower than break-even (open + BE) and 
				// is stop loss lower than where it should be
				{
					if (Bid<sl)
					// if bid lower than buy trade stop loss level, close 
					{
						Write(logfile,"Stop Loss of Buy Order Hit at "+DoubleToString(sl,_Digits)+", Closing at "+DoubleToString(Bid,_Digits));
						if ( ! Trade.PositionClose(_Symbol,0)) {
							Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
						}
					}
					if (Bid>sl) 
					// if bid higher than sl, reset stop loss and take profit
					{
						Write(logfile,"Stop Loss of Buy Order Reset to "+DoubleToString(sl,_Digits)+", Take Profit of Buy Order Reset to "+DoubleToString(tp,_Digits)+" at "+DoubleToString(Bid,_Digits));
						if ( ! Trade.PositionModify(_Symbol,sl,tp)) {
							Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
						}
					}
				}
			}
			if (BEPoints!=0 && Bid>be) {
				if (otp<tp || otp>tp) 
				// is bid higher than break-even (open + BE) and 
				// is take profit other than where it should be
				{
					Write(logfile,"Stop Loss of Buy Order Moved to BE at "+DoubleToString(of,_Digits)+", Take Profit of Buy Order Reset to "+DoubleToString(tp,_Digits)+" at "+DoubleToString(Bid,_Digits));
					if ( ! Trade.PositionModify(_Symbol,of,tp)) {
						Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
					}
				}
			}
		}
		if (PositionInfo.PositionType() == POSITION_TYPE_SELL) {
			be=PositionInfo.PriceOpen()-((BEPoints+BEOffset)*_Point);
			of=PositionInfo.PriceOpen()-(BEOffset*_Point);
			tp=PositionInfo.PriceOpen()-(TP*_Point);
			slippage=NormalizeDouble((otp-tp)/_Point,0); // slippage is how far Take Profit is out by
			if (MaxSlippage!=0 && slippage>MaxSlippage) // if slippage exceeds maxslippage
			{
				if (AddSpreadToSL) { // set MinStop
					sl=PositionInfo.PriceOpen()+sp+ (MinStopLevel*_Point);
				}
				else {
					sl=PositionInfo.PriceOpen()+(MinStopLevel*_Point);
				}
				Write(logfile,"Slippage of Sell Order was "+DoubleToString(slippage,0)+", exceeded MaxSlippage of "+DoubleToString(MaxSlippage)+", setting MinStop to "+DoubleToString(sl,_Digits));
			}
			else // if slippage does not exceed maxslippage
			{
				if (slippage>0) { //output slippage to log
					Write(logfile,"Slippage of Sell Order was "+DoubleToString(slippage,0));
				}
				if (AddSpreadToSL) { // set normal stop
					sl=PositionInfo.PriceOpen()+sp+(SL*_Point);
				}
				else {
					sl=PositionInfo.PriceOpen()+(SL*_Point);
				}
			}
			if (Ask<tp) 
			// if ask lower than sell take profit level, close
			{
				Write(logfile,"Take Profit of Sell Order Hit at "+DoubleToString(tp,_Digits)+", Closing at "+DoubleToString(Ask,_Digits));
				if ( ! Trade.PositionClose(_Symbol,0)) {
					Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
				}
			}
			if (BEPoints==0 || Ask>be) {
				if (osl>sl)
				// is ask higher than break-even (open - BE) and 
				// is stop loss higher than where it should be
				{
					if (Ask>sl) 
					// if ask higher than sell trade stop loss level, close
					{
						Write(logfile,"Stop Loss of Sell Order Hit at "+DoubleToString(sl,_Digits)+", Closing at "+DoubleToString(Ask,_Digits));
						if ( ! Trade.PositionClose(_Symbol,0)) {
							Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
						}
					}
					if (Ask<sl) 
					// if ask lower than sl, reset stop loss and take profit
					{ 
						Write(logfile,"Stop Loss of Sell Order Reset to "+DoubleToString(sl,_Digits)+", Take Profit of Sell Order Reset to "+DoubleToString(tp,_Digits)+" at "+DoubleToString(Bid,_Digits));
						if ( ! Trade.PositionModify(_Symbol,sl,tp)) {
							Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
						}
					}
				}
			}
			if (BEPoints!=0 && Ask<be) {
				if (otp<tp || otp>tp) 
				// is take profit other than where it should be
				{
					Write(logfile,"Stop Loss of Sell Order Moved to BE at "+DoubleToString(of,_Digits)+", Take Profit of Sell Order Reset to "+DoubleToString(tp,_Digits)+" at "+DoubleToString(Bid,_Digits));
					if ( ! Trade.PositionModify(_Symbol,of,tp)) {
						Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
					}
				}
			}
		}
	}
}


//+------------------------------------------------------------------+
//| Reset Stop Loss to Correct Distance                              |
//+------------------------------------------------------------------+
void DoSL()
{
	double Ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
	double Bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
	double osl,be,sl;
	if (PositionInfo.Select(_Symbol) && (PositionInfo.Magic()==Magic)) { // only look if mygrid and symbol...
		osl=PositionInfo.StopLoss();
		if (PositionInfo.PositionType() == POSITION_TYPE_BUY) {
			be=PositionInfo.PriceOpen()+((BEPoints+BEOffset)*_Point);
			if (AddSpreadToSL)
			{
				sl=PositionInfo.PriceOpen()-sp-(SL*_Point);
			}
			else
			{
				sl=PositionInfo.PriceOpen()-(SL*_Point);
			}
			if (BEPoints==0 || Bid<be){
				if (osl<sl) 
				// is bid lower than break-even (open + BE) and 
				// is stop loss lower than where it should be
				{
					if (Bid<sl)
					// if bid lower than buy trade stop loss level, close 
					{
						Write(logfile,"Stop Loss of Buy Order Hit at "+DoubleToString(sl,_Digits)+", Closing at "+DoubleToString(Bid,_Digits));
						if ( ! Trade.PositionClose(_Symbol,0)) {
							Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
						}
					}
					if (Bid>sl) 
					// if bid higher than sl, reset stop loss set to open minus stop loss
					{
						Write(logfile,"Stop Loss of Buy Order Reset to "+DoubleToString(sl,_Digits)+", at "+DoubleToString(Bid,_Digits));
						if ( ! Trade.PositionModify(_Symbol,sl,PositionInfo.TakeProfit())) {
							Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
						}
					}
				}
			}
		}
		if (PositionInfo.PositionType() == POSITION_TYPE_SELL) {
			be=PositionInfo.PriceOpen()-((BEPoints+BEOffset)*_Point);
			if (AddSpreadToSL)
			{
				sl=PositionInfo.PriceOpen()+sp+(SL*_Point);
			}
			else
			{
				sl=PositionInfo.PriceOpen()+(SL*_Point);
			}
			if (BEPoints==0 || Ask>be) {
				if (osl>sl)
				// is ask higher than break-even (open - BE) and 
				// is stop loss higher than where it should be
				{
					if (Ask>sl) 
					// if ask higher than sell trade stop loss level, close
					{
						Write(logfile,"Stop Loss of Sell Order Hit at "+DoubleToString(sl,_Digits)+", Closing at "+DoubleToString(Ask,_Digits));
						if ( ! Trade.PositionClose(_Symbol,0)) {
							Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
						}
					}
					if (Ask<sl) 
					// if ask lower than sl reset stop loss set to open plus stop loss
					{ 
						Write(logfile,"Stop Loss of Sell Order Reset to "+DoubleToString(sl,_Digits)+", at "+DoubleToString(Ask,_Digits));
						if ( ! Trade.PositionModify(_Symbol,sl,PositionInfo.TakeProfit())) {
							Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
						}
					}
				}
			}
		}
	}
}


//+------------------------------------------------------------------+
//| Reset Take Profit to Correct Distance                            |
//+------------------------------------------------------------------+
void DoTP()
{
	double Ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
	double Bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
	double slippage;
	double otp,tp;
	if (PositionInfo.Select(_Symbol) && (PositionInfo.Magic()==Magic)) { // only look if mygrid and symbol...
		otp=PositionInfo.TakeProfit();
		if (PositionInfo.PositionType() == POSITION_TYPE_BUY) {
			tp=PositionInfo.PriceOpen()+(TP*_Point);
			slippage=NormalizeDouble((tp - otp)/_Point,0); // slippage is how far Take Profit is out by
			if (slippage>0) { //output slippage to log
				Write(logfile,"Slippage of Buy Order was "+DoubleToString(slippage,0));
			}
			if (otp<tp || otp>tp) 
			// is take profit other than where it should be
			{
				if (Bid>tp)
				// if bid higher than buy take profit level, close
				{
					Write(logfile,"Take Profit of Buy Order Hit at "+DoubleToString(tp,_Digits)+", Closing at "+DoubleToString(Bid,_Digits));
					if ( ! Trade.PositionClose(_Symbol,0)) {
						Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
					}
				}
				if (Bid<tp) 
				// if bid lower than tp, reset take profit to open plus take profit setting
				{
					Write(logfile,"Take Profit of Buy Order Reset to "+DoubleToString(tp,_Digits)+", at "+DoubleToString(Bid,_Digits));
					if ( ! Trade.PositionModify(_Symbol,PositionInfo.StopLoss(),tp)) {
						Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
					}
				}
			}
		}
		if (PositionInfo.PositionType() == POSITION_TYPE_SELL) {
			tp=PositionInfo.PriceOpen() - (TP * _Point);
			slippage=NormalizeDouble((otp-tp)/_Point,0); // slippage is how far Take Profit is out by
			if (slippage>0) { //output slippage to log
				Write(logfile,"Slippage of Sell Order was "+DoubleToString(slippage,0));
			}
			if (otp<tp || otp>tp)
			// is take profit other than where it should be
			{
				if (Ask<tp) 
				// if ask lower than sell take profit level, close
				{
					Write(logfile,"Take Profit of Sell Order Hit at "+DoubleToString(tp,_Digits)+", Closing at "+DoubleToString(Ask,_Digits));
					if ( ! Trade.PositionClose(_Symbol,0)) {
						Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
					}
				}
				if (Ask>tp) 
				// if ask higher than sl, reset take profit set to open minus take profit setting
				{ 
					Write(logfile,"Take Profit of Sell Order Reset to "+DoubleToString(tp,_Digits)+", at "+DoubleToString(Ask,_Digits));
					if ( ! Trade.PositionModify(_Symbol,PositionInfo.StopLoss(),tp)) {
						Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
					}
				}
			}
		}
	}
}


//+------------------------------------------------------------------+
//| Move Stop Loss to Break Even if Needed                           |
//+------------------------------------------------------------------+
void DoBE()
{
	double Ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
	double Bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
	double osl,be,of;
	if (PositionInfo.Select(_Symbol) && (PositionInfo.Magic()==Magic)) { // only look if mygrid and symbol...
		osl=PositionInfo.StopLoss();
		if (PositionInfo.PositionType() == POSITION_TYPE_BUY) {
			be=PositionInfo.PriceOpen()+((BEPoints+BEOffset)*_Point);
			of=PositionInfo.PriceOpen()+(BEOffset*_Point);
			if (NormalizeDouble(osl,_Digits)<NormalizeDouble(of,_Digits) || osl==0)
			// is stop loss lower than open plus BE offset
			{
				if (Bid>be) 
				// is bid higher than break-even (open + BE)
				{
					Write(logfile,"Break Even of Buy Order set to "+DoubleToString(of,_Digits)+" at "+DoubleToString(Bid,_Digits));
					if ( ! Trade.PositionModify(_Symbol,of,PositionInfo.TakeProfit())) {
						Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
					}
				}
				if (Bid<osl && osl!=0)
				// if bid lower than buy trade stop loss level, close 
				{
					Write(logfile,"Stop Loss of Buy Order Hit at "+DoubleToString(osl,_Digits)+", Closing at "+DoubleToString(Bid,_Digits));
					if ( ! Trade.PositionClose(_Symbol,0)) {
						Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
					}
				}
			}
		}
		if (PositionInfo.PositionType() == POSITION_TYPE_SELL) {
			be=PositionInfo.PriceOpen()-((BEPoints+BEOffset)*_Point);
			of=PositionInfo.PriceOpen()-(BEOffset*_Point);
			if (NormalizeDouble(osl,_Digits)>NormalizeDouble(of,_Digits) || osl==0)
			// is stop loss higher than open minus BE offset
			{
				if (Ask<be)
				// is ask lower than break-even (open - BE)
				{
					Write(logfile,"Break Even of Sell Order set to "+DoubleToString(of,_Digits)+" at "+DoubleToString(Ask,_Digits));
					if ( ! Trade.PositionModify(_Symbol,of,PositionInfo.TakeProfit())) {
						Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
					}
				}
				if (Ask>osl && osl!=0) 
				// if ask higher than sell trade stop loss level, close
				{
					Write(logfile,"Stop Loss of Sell Order Hit at "+DoubleToString(osl,_Digits)+", Closing at "+DoubleToString(Ask,_Digits));
					if ( ! Trade.PositionClose(_Symbol,0)) {
						Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
					}
				}
			}
		}
	}
}

//+------------------------------------------------------------------+
//| Move Trailing Stop if Needed                                     |
//+------------------------------------------------------------------+
void DoTrail()
{
	double Ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
	double Bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
	double osl,to,tl;
	if (PositionInfo.Select(_Symbol) && (PositionInfo.Magic()==Magic)) { // only look if mygrid and symbol...
		osl=PositionInfo.StopLoss();
		if (PositionInfo.PositionType() == POSITION_TYPE_BUY) {
			to=PositionInfo.PriceOpen()+((TrailPoints+TrailOffset)*_Point);
			tl=Bid-(TrailPoints*_Point);
			if ((!TrailImmediate && Bid>to) || TrailImmediate) 
			// is bid higher than open plus trail and offset setting or is TrailImmediate=true
			{
				if (NormalizeDouble(osl,_Digits)<NormalizeDouble(tl,_Digits) || osl==0)
				// is stop loss less than bid minus the trail setting
				{
					Write(logfile,"Trailing Stop of Buy Order set to "+DoubleToString(tl,_Digits)+" at "+DoubleToString(Bid,_Digits));
					if ( ! Trade.PositionModify(_Symbol,tl,PositionInfo.TakeProfit())) {
						Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
					}
				}
			}
			if (Bid<osl && osl!=0)
			// if bid lower than buy stop level, close 
			{
				Write(logfile,"Stop Loss of Buy Order Hit at "+DoubleToString(osl,_Digits)+", Closing at "+DoubleToString(Bid,_Digits));
				if ( ! Trade.PositionClose(_Symbol,0)) {
					Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
				}
			}
		}
		if (PositionInfo.PositionType() == POSITION_TYPE_SELL) {
			to=PositionInfo.PriceOpen()-((TrailPoints+TrailOffset)*_Point);
			tl=Ask+(TrailPoints*_Point);
			if ((!TrailImmediate && Ask<to) || TrailImmediate) 
			// is ask lower than open minus trail and offset setting or is TrailImmediate=true
			{
				if (NormalizeDouble(osl,_Digits)>NormalizeDouble(tl,_Digits) || osl==0)
				// is stop loss higher than ask plus the trail setting
				{
					Write(logfile,"Trailing Stop of Sell Order set to "+DoubleToString(tl,_Digits)+" at "+DoubleToString(Ask,_Digits));
					if ( ! Trade.PositionModify(_Symbol,tl,PositionInfo.TakeProfit())) {
						Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
					}
				}
			}
			if (Ask>osl && osl!=0) 
			// if ask higher than sell stop level, close
			{
				Write(logfile,"Stop Loss of Sell Order Hit at "+DoubleToString(osl,_Digits)+", Closing at "+DoubleToString(Ask,_Digits));
				if ( ! Trade.PositionClose(_Symbol,0)) {
					Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
				}
			}
		}
	}
}

//+------------------------------------------------------------------+
//| Delete Pending Buy Stop Order                                    |
//+------------------------------------------------------------------+
void DeleteBuyStop()
{
	for (int i=OrdersTotal()-1; i>=0; i--) {
		ulong ticket = OrderGetTicket(i);
		if (OrderInfo.Select(ticket)) {
			if ((OrderInfo.Symbol() == _Symbol) && (OrderInfo.Magic() == Magic) && (OrderInfo.OrderType() == ORDER_TYPE_BUY_STOP)) {
				if ( ! Trade.OrderDelete(ticket)) {
					Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
				} 
				else 
				{
					Write(logfile,"DeleteBuyStop, OrderDelete Executed");
				}
			}
		}
	}
}

//+------------------------------------------------------------------+
//| Delete Pending Sell Stop Order                                   |
//+------------------------------------------------------------------+
void DeleteSellStop()
{
	for (int i=OrdersTotal()-1; i>=0; i--) {
		ulong ticket = OrderGetTicket(i);
		if (OrderInfo.Select(ticket)) {
			if ((OrderInfo.Symbol() == _Symbol) && (OrderInfo.Magic() == Magic) && (OrderInfo.OrderType() == ORDER_TYPE_SELL_STOP)) {
				if ( ! Trade.OrderDelete(ticket)) {
					Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
				} 
				else 
				{
					Write(logfile,"DeleteSellStop, OrderDelete Executed");
				}
			}
		}
	}
}

//+------------------------------------------------------------------+
//| Delete All Orders (Prior to Halt)                                |
//+------------------------------------------------------------------+
void OrdersDeleteAll()
{
	DeleteBuyStop();
	DeleteSellStop();
}

//+------------------------------------------------------------------+
//| Logs a String to a File                                          |
//+------------------------------------------------------------------+
void Write(string filename,string str)
{
	ResetLastError();
	int filehandle;

	filehandle = FileOpen(filename,FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_CSV,"/t");
	if(filehandle!=INVALID_HANDLE)
	{
		FileSeek(filehandle, 0, SEEK_END);      
		FileWrite(filehandle, TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS) + " " + str);
		FileClose(filehandle);
	}
	else Print("Error Occurred : "+ErrorDescription(GetLastError()));
}

//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
void OnInit()
{
	Magic=(NHour*10000)+(NMin*100)+NSec; //Unique EA identifier
	MqlDateTime dt;
	TimeCurrent(dt);
	logfile = TradeLog + "-Log-" + _Symbol + "-" + AddLeadingZero(dt.year,4) + "-" + AddLeadingZero(dt.mon,2) + "-" + AddLeadingZero(dt.day,2) + ".log";
	Print(logfile);
	tickfile = TradeLog + "-Ticks-" + _Symbol + "-" + AddLeadingZero(dt.year,4) + "-" + AddLeadingZero(dt.mon,2) + "-" + AddLeadingZero(dt.day,2) + ".csv";
	Print(tickfile);

	MinStopLevel=int(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)); // Min. distance for Stops

	if (ModifyGap>20) { 
		_ModifyGap = 20 ; 
	}
	else  {
		_ModifyGap = ModifyGap ;
	}

	if (SL!=0 && SL<MinStopLevel) { 
		_SL = MinStopLevel ; 
	}
	else  {
		_SL = SL ;
	}

	if (TP!=0 && TP<MinStopLevel) { 
		_TP = MinStopLevel ; 
	}
	else  {
		_TP = TP ;
	}

	if (TrailPoints!=0 && TrailPoints<MinStopLevel) { 
		_TrailPoints = MinStopLevel ; 
	}
	else  {
		_TrailPoints = TrailPoints ;
	}

	if (BEPoints!=0 && BEPoints<MinStopLevel) { 
		_BEPoints = MinStopLevel ; 
	}
	else  {
		_BEPoints = BEPoints ;
	}

	if (OCO) { 
		_OCO = 1 ; 
	}
	else  {
		_OCO = 0 ; 
	}

	//Initialize the Trade class object
	Trade = new CTrade;
	Trade.SetExpertMagicNumber(Magic);
}

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
	if (DeleteOnShutdown)
	Comment("");
	Write(logfile,"Amazing EA shut down");
	delete Trade;
}

//+------------------------------------------------------------------+
//| Expert Every Tick Function                                       |
//+------------------------------------------------------------------+
void OnTick()
{

	double Ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
	double Bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);

	sp=Ask-Bid;
	int spread=int(sp/_Point);
	Write(tickfile,","+DoubleToString(Bid,_Digits)+","+DoubleToString(Ask,_Digits)+","+IntegerToString(spread));

	int secofday,secofnews;
	string brokertime;
	int OrdersCondition=CheckOrdersCondition();

	if (OrdersCondition>11) { // we have open trades, amending stops
		if (SlipCheck && SL!=0 && TP!=0) DoSlip(); // SL and TP both set, reset both and work out slippage
		if (SlipCheck && SL!=0 && TP==0) DoSL(); // SL set so can reset SL, TP not set so can't workout slippage
		if (SlipCheck && SL==0 && TP!=0) DoTP(); // TP set but no SL, no point working out slippage
		if (_TrailPoints!=0) DoTrail(); // perform trailing stop processing
		if (_BEPoints!=0) DoBE(); // perform break even processing
	}

	MqlDateTime brokerdt;
	MqlDateTime localdt;
	TimeCurrent(brokerdt);
	TimeLocal(localdt);

	if (UseBrokerTime) {
		secofday = brokerdt.hour * 3600 + brokerdt.min * 60 + brokerdt.sec;
		brokertime=TimeToString(TimeCurrent(brokerdt),TIME_DATE|TIME_SECONDS); // BrokerTime is shown in the EA Comment.
	}
	else
	{
		secofday=localdt.hour * 3600 + localdt.min * 60 + localdt.sec;
		brokertime=TimeToString(TimeLocal(localdt),TIME_DATE|TIME_SECONDS); // BrokerTime is shown in the EA Comment.
	}

	secofnews=NHour*3600+NMin*60+NSec;
	
	_PointsAway=PointsAway;

	if (SecBPO!=SecBAO && SecBAO!=0 && _PointsAway<PointsGap) {
		if (secofday<secofnews && secofday>(secofnews-SecBPO) && secofday<(secofnews-SecBAO)) 
		{ // if before news but after (news minus BPO) and before (news minus BAO)
			{
				_PointsAway=PointsAway+PointsGap;
			}
		}
	}

	if (SecBPO!=SecBAO && SecBAO!=0 && _PointsAway>=PointsGap) {
		if (secofday<secofnews && secofday>(secofnews-SecBPO) && secofday>=(secofnews-SecBAO)) 
		{ // if before news but after (news minus BPO) and after (news minus BAO)
			{
				_PointsAway=PointsAway;
			}
		}
	}

	if (CTCBN==0) 
	{
		h=Bid;
		l=Bid;
	}
	else
	{
		ResetLastError();
		MqlRates rates[];
		ArraySetAsSeries(rates, true);
		int copied = CopyRates(NULL, 0, 0, CTCBN, rates);
		if (copied <= 0) {
			Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
		}
		h = rates[0].high;
		l = rates[0].low;
		int i;
		for (i=1; i<=CTCBN;i++) if (rates[i-1].high > h) h = rates[i-1].high;
		for (i=1; i<=CTCBN;i++) if (rates[i-1].low < l) l = rates[i-1].low;
	}

	ho=h+sp+(_PointsAway*_Point); 
	if (ho < Ask+(MinStopLevel*_Point)) ho=Ask+(MinStopLevel*_Point); //Ensure orders are MinStopLevel away but only if necessary
	lo=l-(_PointsAway*_Point);
	if (lo > Bid-(MinStopLevel*_Point)) lo=Bid-(MinStopLevel*_Point); //Ensure orders are MinStopLevel away but only if necessary

	if (_SL==0)
	{
		hso = 0;
		lso = 0;
	}
	else if (AddSpreadToSL)
	{
		hso=ho-sp-(_SL*_Point); //Bid+(_PointsAway*_Point)-(_SL*_Point); //hso=Ask+(PipsAway-_SL)*_Point; //hso=h+sp;
		lso=lo+sp+(_SL*_Point); //Ask-(_PointsAway*_Point)+(_SL*_Point); //lso=Bid-(PipsAway-_SL)*_Point; //lso=l;
	}
	else
	{
		hso=ho-(_SL*_Point); //Ask+(_PointsAway*_Point)-(_SL*_Point)
		lso=lo+(_SL*_Point); //Bid-(_PointsAway*_Point)+(_SL*_Point)
	}

	if (_TP==0)
	{
		htp = 0;
		ltp = 0;
	}
	else
	{ 
		htp=ho+(_TP*_Point);
		ltp=lo-(_TP*_Point);
	}

	string title="Amazing Forex System Expert Advisor (MT5) v5.20 By Alan Prothero";
	string newstime,timetitle;
	StringConcatenate(newstime, AddLeadingZero(NYear,4),".",AddLeadingZero(NMonth,2),".",AddLeadingZero(NDay,2)," ",TimeToString(secofnews,TIME_SECONDS));
	StringConcatenate(timetitle,"System Time : ", brokertime, "\nNews Time    : ", newstime);
	string DisplayOCO="False";
	if (OCO) DisplayOCO="True";
	string DisplayMM="False";
	if (MM) DisplayMM="True";
	string DisplayAddSpreadToSL="False";
	if (AddSpreadToSL) DisplayAddSpreadToSL="True";
	string DisplaySlipCheck="False";
	if (SlipCheck) DisplaySlipCheck="True";
	string DisplayTrailImmediate="False";
	if (TrailImmediate) DisplayTrailImmediate="True";
	string DisplayAllowBuys="False";
	if (AllowBuys) DisplayAllowBuys="True";
	string DisplayAllowSells="False";
	if (AllowSells) DisplayAllowSells="True";
	string DisplayUseBrokerTime="False";
	if (UseBrokerTime) DisplayUseBrokerTime="True";
	string DisplayDeleteOnShutdown="False";
	if (DeleteOnShutdown) DisplayDeleteOnShutdown="True";
	string Comment1,Comment2,Comment3,Comment4,Comment5,Comment6,Comment7,Comment8,Comment9,CommentA;
	StringConcatenate(Comment1,"High @ ",DoubleToString(h,_Digits)," BuyOrder @ ",DoubleToString(ho,_Digits)," StopLoss @ ",DoubleToString(hso,_Digits)," TakeProfit @ ",DoubleToString(htp,_Digits));
	StringConcatenate(Comment2,"Low  @ ",DoubleToString(l,_Digits)," SellOrder @ ",DoubleToString(lo,_Digits)," StopLoss @ ",DoubleToString(lso,_Digits)," TakeProfit @ ",DoubleToString(ltp,_Digits));
	StringConcatenate(Comment3,"PointsAway : ",_PointsAway," | PointsGap : ",PointsGap," | ModifyGap : ",_ModifyGap);
	StringConcatenate(Comment4,"BEOffset : ",BEOffset," | BEPoints : ",_BEPoints," | TrailOffset : ", TrailOffset," | TrailPoints : ", _TrailPoints);
	StringConcatenate(Comment5,"CTCBN : ",CTCBN," | SecBPO : ",SecBPO," | SecBAO : ",SecBAO," | SecBMO : ",SecBMO," | STWAN : ",STWAN," | OCO : ",DisplayOCO);
	StringConcatenate(Comment6,"Money Management : ",DisplayMM," | RiskPercent: ",RiskPercent," | Lots : ",LotsOptimized());
	StringConcatenate(Comment7,"AddSpreadToSL : ",DisplayAddSpreadToSL," | SlipCheck : ",DisplaySlipCheck," | TrailImmediate : ",DisplayTrailImmediate);
	StringConcatenate(Comment8,"MaxSlippage : ",MaxSlippage," | MaxSpread : ",MaxSpread," | Spread : ",spread);
	StringConcatenate(Comment9,"AllowBuys : ",DisplayAllowBuys," | AllowSells : ",DisplayAllowSells);
	StringConcatenate(CommentA,"UseBrokerTime : ",DisplayUseBrokerTime," | DeleteOnShutdown : ",DisplayDeleteOnShutdown);

	// TradeComment gets added in the Comment field of trades. Max 32 chars.
	if (_PointsAway>=PointsGap) 
	{ 
		StringConcatenate(TradeComment,"P", _PointsAway-PointsGap, "T", _TP, "S", _SL, "C", CTCBN, "P", SecBPO, "A", SecBAO, "M", SecBMO, "W", STWAN, "O", _OCO, "B", _BEPoints, "T", _TrailPoints);
	}
	else
	{
		StringConcatenate(TradeComment,"P", _PointsAway, "T", _TP, "S", _SL, "C", CTCBN, "P", SecBPO, "A", SecBAO, "M", SecBMO, "W", STWAN, "O", _OCO, "B", _BEPoints, "T", _TrailPoints );
	}

	if (MaxSpread!=0)
	{
		if (spread>MaxSpread) {
			Write(logfile,"MaxSpread Exceeded, MaxSpread: "+IntegerToString(MaxSpread)+" Spread : "+IntegerToString(spread));
			OrdersDeleteAll();
			Comment("\n",title,"\n\n",timetitle,"\n\n","MaxSpread : ",MaxSpread," | Spread : ",spread,"\n\n","Expert is disabled because Spread exceeds MaxSpread Setting");
			// Despite the comment above, the expert is not really disabled, it just exits without trading.
			// The return statement below is very important as it ensures the EA exits without opening trades if the Spread is too high.
			Sleep(5000); // Suspend for 5 seconds
		}
	}

	if ((!UseBrokerTime && NYear==localdt.year && NMonth==localdt.mon && NDay==localdt.day) || (UseBrokerTime && NYear==brokerdt.year && NMonth==brokerdt.mon && NDay==brokerdt.day) || (NYear==0 && NMonth==0 && NDay==0))
	{
		Comment("\n",title,"\n\n",timetitle,"\n\n",Comment1,"\n", Comment2,"\n\n", Comment3,"\n\n",Comment4,"\n\n",Comment5,"\n\n",Comment6,"\n\n",Comment7,"\n\n",Comment8,"\n\n",Comment9,"\n\n",CommentA);
	}
	else
	{
		Comment("\n",title,"\n\n",timetitle,"\n\n","Expert is disabled because it is not day of expected news");
		// Despite the comment above, the expert is not really disabled, it just exits without trading.
		// The return statement below is very important as it ensures the EA exits without opening trades on non-news days. 
	} 

	// OrdersCondition Result Pattern
	//    1    1    1    1
	//    b    s    bs   ss
	//

	if (secofday<secofnews && secofday>(secofnews-SecBPO)) 
	{ // if before news but after news minus BPO
		if (OrdersCondition==0) { // if we have no orders
			Write(logfile,title);
			if (AllowBuys) { // if buys are allowed
				Write(logfile,"Opening BuyStop @ "+DoubleToString(ho,_Digits)+", OrdersCondition="+IntegerToString(OrdersCondition));
				OpenBuyStop();
			}
			if (AllowSells) { // if sells are allowed
				Write(logfile,"Opening SellStop @ "+DoubleToString(lo,_Digits)+", OrdersCondition="+IntegerToString(OrdersCondition));
				OpenSellStop();
			}
		}
		if (OrdersCondition==1 && AllowBuys) { // if we only have a sell stop and buys are allowed
			Write(logfile,"Opening BuyStop @ "+DoubleToString(ho,_Digits)+", OrdersCondition="+IntegerToString(OrdersCondition));
			OpenBuyStop();
		}
		if (OrdersCondition==10 && AllowSells) { // if we only have a buy stop and sells are allowed
			Write(logfile,"Opening SellStop @ "+DoubleToString(lo,_Digits)+", OrdersCondition="+IntegerToString(OrdersCondition));
			OpenSellStop();
		}
	}

	if (secofday<(secofnews+STWAN) && secofday>(secofnews-SecBPO) && (secofday>(secofnews-SecBAO)||PointsGap==0||SecBAO==0) && secofday<(secofnews-SecBMO)) 
	{ // if before STWAN but after news minus BPO and after news minus BAO and before news minus BMO (allows negative BMO)
		// if PointsGap is 0, or SecBAO is 0, then SecBAO is ignored
		Write(logfile,"Modifying Orders, OrdersCondition="+IntegerToString(OrdersCondition));
		DoModify();
	}

	if (secofday>secofnews && secofday<(secofnews+STWAN) && OCO) 
	{ // if after news and within wait time and we are using one cancels other
		if (OrdersCondition==1001) { // if we have a buy and a sell stop
			Write(logfile,"Deleting SellStop because BuyStop Hit, OrdersCondition="+IntegerToString(OrdersCondition));
			DeleteSellStop();
		}
		if (OrdersCondition==110) { // if we have a sell and a buy stop
			Write(logfile,"Deleting BuyStop because SellStop Hit, OrdersCondition="+IntegerToString(OrdersCondition));
			DeleteBuyStop();
		}
	}

	if (secofday>secofnews && secofday>(secofnews+STWAN)) 
	{ // if after news and after wait time 
		if (OrdersCondition==11) { // if we have a buy stop and a sell stop
			Write(logfile,"Deleting BuyStop and SellStop because STWAN expired, OrdersCondition="+IntegerToString(OrdersCondition));
			DeleteSellStop();
			DeleteBuyStop();
		}
		if (OrdersCondition==1 || OrdersCondition==1001) { // if we have a sell stop or a buy and a sell stop
			Write(logfile,"Deleting SellStop because STWAN expired, OrdersCondition="+IntegerToString(OrdersCondition));
			DeleteSellStop();
		}
		if (OrdersCondition==10 || OrdersCondition==110) { // if we have a buy stop or a sell and a buy stop
			Write(logfile,"Deleting BuyStop because STWAN expired, OrdersCondition="+IntegerToString(OrdersCondition));
			DeleteBuyStop();
		}
	}

}

//+------------------------------------------------------------------+
//| Return Error Code Description                                    |
//+------------------------------------------------------------------+
string ErrorDescription(int error_code)
{
	string error_string;
	//----
	switch(error_code)
	{
		//---- codes returned from trade server
	case 0   : error_string="The operation completed successfully";                                                                                               break;
	case 4001: error_string="Unexpected internal error";                                                                                                          break;
	case 4002: error_string="Wrong parameter in the inner call of the client terminal function";                                                                  break;
	case 4003: error_string="Wrong parameter when calling the system function";                                                                                   break;
	case 4004: error_string="Not enough memory to perform the system function";                                                                                   break;
	case 4005: error_string="The structure contains objects of strings and/or dynamic arrays and/or structure of such objects and/or classes";                    break;
	case 4006: error_string="Array of a wrong type, wrong size, or a damaged object of a dynamic array";                                                          break;
	case 4007: error_string="Not enough memory for the relocation of an array, or an attempt to change the size of a static array";                               break;
	case 4008: error_string="Not enough memory for the relocation of string";                                                                                     break;
	case 4009: error_string="Not initialized string";                                                                                                             break;
	case 4010: error_string="Invalid date and/or time";                                                                                                           break;
	case 4011: error_string="Requested array size exceeds 2 GB";                                                                                                  break;
	case 4012: error_string="Wrong pointer";                                                                                                                      break;
	case 4013: error_string="Wrong type of pointer";                                                                                                              break;
	case 4014: error_string="Function is not allowed for call";                                                                                                   break;
	case 4015: error_string="The names of the dynamic and the static resource match";                                                                             break;
	case 4016: error_string="Resource with this name has not been found in EX5";                                                                                  break;
	case 4017: error_string="Unsupported resource type or its size exceeds 16 Mb";                                                                                break;
	case 4018: error_string="The resource name exceeds 63 characters";                                                                                            break;
		//---- Charts
	case 4101: error_string="Wrong chart ID";                                                                                                                     break;
	case 4102: error_string="Chart does not respond";                                                                                                             break;
	case 4103: error_string="Chart not found";                                                                                                                    break;
	case 4104: error_string="No Expert Advisor in the chart that could handle the event";                                                                         break;
	case 4105: error_string="Chart opening error";                                                                                                                break;
	case 4106: error_string="Failed to change chart symbol and period";                                                                                           break;
	case 4107: error_string="Error value of the parameter for the function of working with charts";                                                               break;
	case 4108: error_string="Failed to create timer";                                                                                                             break;
	case 4109: error_string="Wrong chart property ID";                                                                                                            break;
	case 4110: error_string="Error creating screenshots";                                                                                                         break;
	case 4111: error_string="Error navigating through chart";                                                                                                     break;
	case 4112: error_string="Error applying template";                                                                                                            break;
	case 4113: error_string="Subwindow containing the indicator was not found";                                                                                   break;
	case 4114: error_string="Error adding an indicator to chart";                                                                                                 break;
	case 4115: error_string="Error deleting an indicator from the chart";                                                                                         break;
	case 4116: error_string="Indicator not found on the specified chart";                                                                                         break;
		//---- Graphical Objects
	case 4201: error_string="Error working with a graphical object";                                                                                              break;
	case 4202: error_string="Graphical object was not found";                                                                                                     break;
	case 4203: error_string="Wrong ID of a graphical object property";                                                                                            break;
	case 4204: error_string="Unable to get date corresponding to the value";                                                                                      break;
	case 4205: error_string="Unable to get value corresponding to the date";                                                                                      break;
		//---- MarketInfo
	case 4301: error_string="Unknown symbol";                                                                                                                     break;
	case 4302: error_string="Symbol is not selected in MarketWatch";                                                                                              break;
	case 4303: error_string="Wrong identifier of a symbol property";                                                                                              break;
	case 4304: error_string="Time of the last tick is not known (no ticks)";                                                                                      break;
	case 4305: error_string="Error adding or deleting a symbol in MarketWatch";                                                                                   break;
		//---- History Access
	case 4401: error_string="Requested history not found";                                                                                                        break;
	case 4402: error_string="Wrong ID of the history property";                                                                                                   break;
		//---- Global_Variables
	case 4501: error_string="Global variable of the client terminal is not found";                                                                                break;
	case 4502: error_string="Global variable of the client terminal with the same name already exists";                                                           break;
	case 4510: error_string="Email sending failed";                                                                                                               break;
	case 4511: error_string="Sound playing failed";                                                                                                               break;
	case 4512: error_string="Wrong identifier of the program property";                                                                                           break;
	case 4513: error_string="Wrong identifier of the terminal property";                                                                                          break;
	case 4514: error_string="File sending via ftp failed";                                                                                                        break;
	case 4515: error_string="Failed to send a notification";                                                                                                      break;
	case 4516: error_string="Invalid parameter for sending a notification– an empty string or NULL has been passed to the SendNotification() function";           break;
	case 4517: error_string="Wrong settings of notifications in the terminal (ID is not specified or permission is not set)";                                     break;
	case 4518: error_string="Too frequent sending of notifications";                                                                                              break;
		//---- Custom Indicator Buffers
	case 4601: error_string="Not enough memory for the distribution of indicator buffers";                                                                        break;
	case 4602: error_string="Wrong indicator buffer index";                                                                                                       break;
		//---- Custom Indicator Properties
	case 4603: error_string="Wrong ID of the custom indicator property";                                                                                          break;
		//---- Account
	case 4701: error_string="Wrong account property ID";                                                                                                          break;
	case 4751: error_string="Wrong trade property ID";                                                                                                            break;
	case 4752: error_string="Trading by Expert Advisors prohibited";                                                                                              break;
	case 4753: error_string="Position not found";                                                                                                                 break;
	case 4754: error_string="Order not found";                                                                                                                    break;
	case 4755: error_string="Deal not found";                                                                                                                     break;
	case 4756: error_string="Trade request sending failed";                                                                                                       break;
		//---- Indicators
	case 4801: error_string="Unknown symbol";                                                                                                                     break;
	case 4802: error_string="Indicator cannot be created";                                                                                                        break;
	case 4803: error_string="Not enough memory to add the indicator";                                                                                             break;
	case 4804: error_string="The indicator cannot be applied to another indicator";                                                                               break;
	case 4805: error_string="Error applying an indicator to chart";                                                                                               break;
	case 4806: error_string="Requested data not found";                                                                                                           break;
	case 4807: error_string="Wrong indicator handle";                                                                                                             break;
	case 4808: error_string="Wrong number of parameters when creating an indicator";                                                                              break;
	case 4809: error_string="No parameters when creating an indicator";                                                                                           break;
	case 4810: error_string="The first parameter in the array must be the name of the custom indicator";                                                          break;
	case 4811: error_string="Invalid parameter type in the array when creating an indicator";                                                                     break;
	case 4812: error_string="Wrong index of the requested indicator buffer";                                                                                      break;
		//---- Depth of Market
	case 4901: error_string="Depth Of Market can not be added";                                                                                                   break;
	case 4902: error_string="Depth Of Market can not be removed";                                                                                                 break;
	case 4903: error_string="The data from Depth Of Market can not be obtained";                                                                                  break;
	case 4904: error_string="Error in subscribing to receive new data from Depth Of Market";                                                                      break;
		//---- File Operations
	case 5001: error_string="More than 64 files cannot be opened at the same time";                                                                               break;
	case 5002: error_string="Invalid file name";                                                                                                                  break;
	case 5003: error_string="Too long file name";                                                                                                                 break;
	case 5004: error_string="File opening error";                                                                                                                 break;
	case 5005: error_string="Not enough memory for cache to read";                                                                                                break;
	case 5006: error_string="File deleting error";                                                                                                                break;
	case 5007: error_string="A file with this handle was closed, or was not opening at all";                                                                      break;
	case 5008: error_string="Wrong file handle";                                                                                                                  break;
	case 5009: error_string="The file must be opened for writing";                                                                                                break;
	case 5010: error_string="The file must be opened for reading";                                                                                                break;
	case 5011: error_string="The file must be opened as a binary one";                                                                                            break;
	case 5012: error_string="The file must be opened as a text";                                                                                                  break;
	case 5013: error_string="The file must be opened as a text or CSV";                                                                                           break;
	case 5014: error_string="The file must be opened as CSV";                                                                                                     break;
	case 5015: error_string="File reading error";                                                                                                                 break;
	case 5016: error_string="String size must be specified, because the file is opened as binary";                                                                break;
	case 5017: error_string="A text file must be for string arrays, for other arrays - binary";                                                                   break;
	case 5018: error_string="This is not a file, this is a directory";                                                                                            break;
	case 5019: error_string="File does not exist";                                                                                                                break;
	case 5020: error_string="File can not be rewritten";                                                                                                          break;
	case 5021: error_string="Wrong directory name";                                                                                                               break;
	case 5022: error_string="Directory does not exist";                                                                                                           break;
	case 5023: error_string="This is a file, not a directory";                                                                                                    break;
	case 5024: error_string="The directory cannot be removed";                                                                                                    break;
	case 5025: error_string="Failed to clear the directory (probably one or more files are blocked and removal operation failed)";                                break;
	case 5026: error_string="Failed to write a resource to a file";                                                                                               break;
		//---- String Casting
	case 5030: error_string="No date in the string";                                                                                                              break;
	case 5031: error_string="Wrong date in the string";                                                                                                           break;
	case 5032: error_string="Wrong time in the string";                                                                                                           break;
	case 5033: error_string="Error converting string to date";                                                                                                    break;
	case 5034: error_string="Not enough memory for the string";                                                                                                   break;
	case 5035: error_string="The string length is less than expected";                                                                                            break;
	case 5036: error_string="Too large number, more than ULONG_MAX";                                                                                              break;
	case 5037: error_string="Invalid format string";                                                                                                              break;
	case 5038: error_string="Amount of format specifiers more than the parameters";                                                                               break;
	case 5039: error_string="Amount of parameters more than the format specifiers";                                                                               break;
	case 5040: error_string="Damaged parameter of string type";                                                                                                   break;
	case 5041: error_string="Position outside the string";                                                                                                        break;
	case 5042: error_string="0 added to the string end, a useless operation";                                                                                     break;
	case 5043: error_string="Unknown data type when converting to a string";                                                                                      break;
	case 5044: error_string="Damaged string object";                                                                                                              break;
		//---- Operations with Arrays
	case 5050: error_string="Copying incompatible arrays. String array can be copied only to a string array, and a numeric array - in numeric array only";        break;
	case 5051: error_string="The receiving array is declared as AS_SERIES, and it is of insufficient size";                                                       break;
	case 5052: error_string="Too small array, the starting position is outside the array";                                                                        break;
	case 5053: error_string="An array of zero length";                                                                                                            break;
	case 5054: error_string="Must be a numeric array";                                                                                                            break;
	case 5055: error_string="Must be a one-dimensional array";                                                                                                    break;
	case 5056: error_string="Timeseries cannot be used";                                                                                                          break;
	case 5057: error_string="Must be an array of type double";                                                                                                    break;
	case 5058: error_string="Must be an array of type float";                                                                                                     break;
	case 5059: error_string="Must be an array of type long";                                                                                                      break;
	case 5060: error_string="Must be an array of type int";                                                                                                       break;
	case 5061: error_string="Must be an array of type short";                                                                                                     break;
	case 5062: error_string="Must be an array of type char";                                                                                                      break;
		//---- Operations with OpenCL
	case 5100: error_string="OpenCL functions are not supported on this computer";                                                                                break;
	case 5101: error_string="Internal error occurred when running OpenCL";                                                                                        break;
	case 5102: error_string="Invalid OpenCL handle";                                                                                                              break;
	case 5103: error_string="Error creating the OpenCL context";                                                                                                  break;
	case 5104: error_string="Failed to create a run queue in OpenCL";                                                                                             break;
	case 5105: error_string="Error occurred when compiling an OpenCL program";                                                                                    break;
	case 5106: error_string="Too long kernel name (OpenCL kernel)";                                                                                               break;
	case 5107: error_string="Error creating an OpenCL kernel";                                                                                                    break;
	case 5108: error_string="Error occurred when setting parameters for the OpenCL kernel";                                                                       break;
	case 5109: error_string="OpenCL program runtime error";                                                                                                       break;
	case 5110: error_string="Invalid size of the OpenCL buffer";                                                                                                  break;
	case 5111: error_string="Invalid offset in the OpenCL buffer";                                                                                                break;
	case 5112: error_string="Failed to create and OpenCL buffer";                                                                                                 break;
		//---- Operations with WebRequest
	case 5200: error_string="Invalid URL";                                                                                                                        break;
	case 5201: error_string="Failed to connect to specified URL";                                                                                                 break;
	case 5202: error_string="Timeout exceeded";                                                                                                                   break;
	case 5203: error_string="HTTP request failed";                                                                                                                break;
		default  : error_string="Unknown Error";
	}
	//----
	return(error_string);
}  
//+------------------------------------------------------------------+
