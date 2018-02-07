//+------------------------------------------------------------------+
//|        AmazingEA.mq4 MetaTrader 4 Version 5.20 By Alan Prothero  |
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

extern int PointsAway=80; // PointsAway, distance to orders.
extern int PointsGap=2000; // PointsGap, extra initial distance to orders.
extern int ModifyGap=10; // ModifyGap, price change needed to modify.
extern int TP=1000; // TP, Take Profit (0=disable).
extern int SL=100; // SL, Stop Loss (0=disable).
extern int NYear=0;  // NYear, News Year (0=trade EA every day).
extern int NMonth=0;  // NMonth, News Month (0=trade EA every day).
extern int NDay=0;  // NDay, News Day (0=trade EA every day).
extern int NHour=0; // NHour, News Hour.
extern int NMin=0;  // NMin, News Minute.
extern int NSec=0;  // NSec, News Second.
extern int CTCBN=0; // CTCBN, Candles To Check Before News (0=disable).
extern int SecBPO=20; // SecBPO, Seconds Before Pending Orders.
extern int SecBAO=5; // SecBAO, Seconds Before Adjacent Orders.
extern int SecBMO=0; // SecBMO, Seconds Before Modifying Orders.
extern int STWAN=5; // STWAN, Seconds To Wait After News (0=disable).
extern bool OCO=true; // OCO, Order Cancel Other.
extern int BEPoints=0; // BEPoints, Break Even Points (0=disable).
extern int BEOffset=0; // BEOffset, Break Even Offset (0=disable).
extern int TrailPoints=0; // TrailPoints, Trailing Stop Points (0=disable).
extern int TrailOffset=0; // TrailOffset, Trailing Stop Offset (0=disable).
extern bool TrailImmediate=false; // TrailImmediate, trail immediately when true.
extern bool MM=false; // MM, Money Management, if true uses RiskPercent.
extern double RiskPercent=2.5; // RiskPercent, overrides Lots.
extern double Lots=0.1; // Lots, Lot Size ()if not MM and RiskPercent).
extern int MaxSpread=60; // MaxSpread, cancels orders if spread exceeds (0=disable).
extern bool AddSpreadToSL=true; // AddSpreadToSL, adds spread to Stop Loss.
extern bool SlipCheck=false; // SlipCheck, checks for slippage and resets Stop Loss.
extern int MaxSlippage=200; // MaxSlippage, close early if exceeded (0=disable).
extern bool AllowBuys=true; // AllowBuys, switch on Buy Trades.
extern bool AllowSells=true; // AllowSells, switch on Sell Trades.
extern bool UseBrokerTime=true; // UseBrokerTime, false uses PC Clock.
extern bool DeleteOnShutdown=true; // DeleteOnShutdown, false keeps Orders.
extern string TradeLog = "AmazingEA"; // TradeLog, Log is created in Experts/Files.
double h,l,ho,lo,hso,lso,htp,ltp,sp;
int Magic,MinStopLevel;
string TradeComment,logfile,tickfile ;

//+------------------------------------------------------------------+
//| Calculate Position Size Depending on Money Management            |
//+------------------------------------------------------------------+
double LotsOptimized()
{
	double lot=Lots;	//---- select lot size
	double minlot = MarketInfo(Symbol(),MODE_MINLOT);
	double lotstep = MarketInfo(Symbol(),MODE_LOTSTEP);
	if (MM) { // if using Money Management
		if (SL!=0) { // if SL is set, take into account Stop Loss Distance
			double risk;
			double ppp = MarketInfo(Symbol(),MODE_TICKVALUE); //PricePerPoint
			if (AddSpreadToSL) { // if AddSpreadToSL is true, add in MaxSpread
				risk=(AccountFreeMargin()*RiskPercent/100)/(SL+MaxSpread);
			}
			else // if AddSpreadToSL is false, just use SL
			{
				risk=(AccountFreeMargin()*RiskPercent/100)/SL;
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
	result = DoubleToStr(number, 0);
	while(StringLen(result)<digits) result = "0"+result;
	return(result);
}

//+------------------------------------------------------------------+
//| Check for Pending Stop Orders and Open Positions                 |
//+------------------------------------------------------------------+
int CheckOrdersCondition()
{
	int result=0;
	for (int i=OrdersTotal()-1; i>=0; i--) {
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
			if (OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==OP_BUY) {
				result=result+1000; 
			}
			if (OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==OP_SELL) {
				result=result+100; 
			}
			if (OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==OP_BUYSTOP) {
				result=result+10;
			}
			if (OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==OP_SELLSTOP) {
				result=result+1; 
			}
		}
	}
	return(result); // 0 means we have no trades
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
	int ticket,tries;
	tries = 0;
	if (!GlobalVariableCheck("InTrade")) {
		while (tries<3)
		{
			GlobalVariableSet("InTrade", CurTime());  // Set Lock Indicator (Semaphore Set)
			ticket = OrderSend(Symbol(),OP_BUYSTOP,LotsOptimized(),ho,1,hso,htp,TradeComment,Magic,0,Green);
			Write(logfile,"OpenBuyStop, OrderSend Executed, @ "+ho+" SL @ "+hso+" TP @ "+htp+" ticket="+ticket);
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
	int ticket,tries;
	tries = 0;
	if (!GlobalVariableCheck("InTrade")) {
		while (tries<3)
		{
			GlobalVariableSet("InTrade", CurTime());  // Set Lock Indicator (Semaphore Set)
			ticket = OrderSend(Symbol(),OP_SELLSTOP,LotsOptimized(),lo,1,lso,ltp,TradeComment,Magic,0,Red);
			Write(logfile,"OpenSellStop, OrderSend Executed, @ "+lo+" SL @ "+lso+" TP @ "+ltp+" ticket="+ticket);
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
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
			if (OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==OP_BUYSTOP) {
				hbp=OrderOpenPrice()+(ModifyGap*Point);
				lbp=OrderOpenPrice()-(ModifyGap*Point);
				if (NormalizeDouble(ho,Digits)>NormalizeDouble(hbp,Digits) || NormalizeDouble(ho,Digits)<NormalizeDouble(lbp,Digits)) {
					Write(logfile,"Buy Stop was @ "+DoubleToStr(OrderOpenPrice(),Digits)+", changed to "+DoubleToStr(ho,Digits));
					if ( ! OrderModify(OrderTicket(),ho,hso,htp,0,Green)) {
						Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
					}
				}
			}
			if (OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==OP_SELLSTOP) {
				hsp=OrderOpenPrice()+(ModifyGap*Point);
				lsp=OrderOpenPrice()-(ModifyGap*Point);
				if (NormalizeDouble(lo,Digits)>NormalizeDouble(hsp,Digits) || NormalizeDouble(lo,Digits)<NormalizeDouble(lsp,Digits)) {
					Write(logfile,"Sell Stop was @ "+DoubleToStr(OrderOpenPrice(),Digits)+", changed to "+DoubleToStr(lo,Digits));
					if ( ! OrderModify(OrderTicket(),lo,lso,ltp,0,Red)) {
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
	int slippage;
	double osl,sl,be,of,otp,tp;
	for (int i=OrdersTotal()-1; i>=0; i--) {
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
			if ((OrderSymbol()==Symbol()) && (OrderMagicNumber()==Magic)) { // only look if mygrid and symbol...
				otp=OrderTakeProfit();
				osl=OrderStopLoss();
				if (OrderType()==OP_BUY) {
					be=OrderOpenPrice()+((BEPoints+BEOffset)*Point);
					of=OrderOpenPrice()+(BEOffset*Point);
					tp=OrderOpenPrice()+(TP*Point);
					slippage=NormalizeDouble((tp - otp)/Point,0); // slippage is how far Take Profit is out by
					if (MaxSlippage!=0 && slippage>MaxSlippage) // if slippage exceeds maxslippage
					{
						if (AddSpreadToSL) { // set MinStop
							sl=OrderOpenPrice()-sp-(MinStopLevel*Point);
						}
						else {
							sl=OrderOpenPrice()-(MinStopLevel*Point);
						}
						Write(logfile,"Slippage of Buy Order was "+slippage+", exceeded MaxSlippage of "+MaxSlippage+", setting MinStop to "+DoubleToStr(sl,Digits));
					}
					else // if slippage does not exceed maxslippage
					{
						if (slippage>0) { //output slippage to log
							Write(logfile,"Slippage of Buy Order was "+slippage);
						}
						if (AddSpreadToSL) { // set normal stop
							sl=OrderOpenPrice()-sp-(SL*Point);
						}
						else {
							sl=OrderOpenPrice()-(SL*Point);
						}
					}
					if (Bid>tp)
					// if bid higher than buy take profit level, close
					{
						Write(logfile,"Take Profit of Buy Order Hit at "+DoubleToStr(tp,Digits)+", Closing at "+DoubleToStr(Bid,Digits));
						if ( ! OrderClose(OrderTicket(),OrderLots(),Bid,0,Green)) {
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
								Write(logfile,"Stop Loss of Buy Order Hit at "+DoubleToStr(sl,Digits)+", Closing at "+DoubleToStr(Bid,Digits));
								if ( ! OrderClose(OrderTicket(),OrderLots(),Bid,0,Green)) {
									Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
								}
							}
							if (Bid>sl) 
							// if bid higher than sl, reset stop loss and take profit
							{
								Write(logfile,"Stop Loss of Buy Order Reset to "+DoubleToStr(sl,Digits)+", Take Profit of Buy Order Reset to "+DoubleToStr(tp,Digits)+" at "+DoubleToStr(Bid,Digits));
								if ( ! OrderModify(OrderTicket(),OrderOpenPrice(),sl,tp,0,Green)) {
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
							Write(logfile,"Stop Loss of Buy Order Moved to BE at "+DoubleToStr(of,Digits)+", Take Profit of Buy Order Reset to "+DoubleToStr(tp,Digits)+" at "+DoubleToStr(Bid,Digits));
							if ( ! OrderModify(OrderTicket(),OrderOpenPrice(),of,tp,0,Green)) {
								Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
							}
						}
					}
				}
				if (OrderType()==OP_SELL) {
					be=OrderOpenPrice()-((BEPoints+BEOffset)*Point);
					of=OrderOpenPrice()-(BEOffset*Point);
					tp=OrderOpenPrice()-(TP*Point);
					slippage=NormalizeDouble((otp-tp)/Point,0); // slippage is how far Take Profit is out by
					if (MaxSlippage!=0 && slippage>MaxSlippage) // if slippage exceeds maxslippage
					{
						if (AddSpreadToSL) { // set MinStop
							sl=OrderOpenPrice()+sp+ (MinStopLevel*Point);
						}
						else {
							sl=OrderOpenPrice()+(MinStopLevel*Point);
						}
						Write(logfile,"Slippage of Sell Order was "+slippage+", exceeded MaxSlippage of "+MaxSlippage+", setting MinStop to "+DoubleToStr(sl,Digits));
					}
					else // if slippage does not exceed maxslippage
					{
						if (slippage>0) { //output slippage to log
							Write(logfile,"Slippage of Sell Order was "+slippage);
						}
						if (AddSpreadToSL) { // set normal stop
							sl=OrderOpenPrice()+sp+(SL*Point);
						}
						else {
							sl=OrderOpenPrice()+(SL*Point);
						}
					}
					if (Ask<tp) 
					// if ask lower than sell take profit level, close
					{
						Write(logfile,"Take Profit of Sell Order Hit at "+DoubleToStr(tp,Digits)+", Closing at "+DoubleToStr(Ask,Digits));
						if ( ! OrderClose(OrderTicket(),OrderLots(),Ask,0,Red)) {
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
								Write(logfile,"Stop Loss of Sell Order Hit at "+DoubleToStr(sl,Digits)+", Closing at "+DoubleToStr(Ask,Digits));
								if ( ! OrderClose(OrderTicket(),OrderLots(),Ask,0,Red)) {
									Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
								}
							}
							if (Ask<sl) 
							// if ask lower than sl, reset stop loss and take profit
							{ 
								Write(logfile,"Stop Loss of Sell Order Reset to "+DoubleToStr(sl,Digits)+", Take Profit of Sell Order Reset to "+DoubleToStr(tp,Digits)+" at "+DoubleToStr(Bid,Digits));
								if ( ! OrderModify(OrderTicket(),OrderOpenPrice(),sl,tp,0,Red)) {
									Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
								}
							}
						}
					}
					if (BEPoints!=0 && Ask<be) {
						if (otp<tp || otp>tp) 
						// is take profit other than where it should be
						{
							Write(logfile,"Stop Loss of Sell Order Moved to BE at "+DoubleToStr(of,Digits)+", Take Profit of Sell Order Reset to "+DoubleToStr(tp,Digits)+" at "+DoubleToStr(Bid,Digits));
							if ( ! OrderModify(OrderTicket(),OrderOpenPrice(),of,tp,0,Red)) {
								Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
							}
						}
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
	double osl,be,sl;
	for (int i=OrdersTotal()-1; i>=0; i--) {
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) { 
			if ((OrderSymbol()==Symbol()) && (OrderMagicNumber()==Magic)) { // only look if mygrid and symbol...
				osl=OrderStopLoss();
				if (OrderType()==OP_BUY) {
					be=OrderOpenPrice()+((BEPoints+BEOffset)*Point);
					if (AddSpreadToSL)
					{
						sl=OrderOpenPrice()-sp-(SL*Point);
					}
					else
					{
						sl=OrderOpenPrice()-(SL*Point);
					}
					if (BEPoints==0 || Bid<be){
						if (osl<sl) 
						// is bid lower than break-even (open + BE) and 
						// is stop loss lower than where it should be
						{
							if (Bid<sl)
							// if bid lower than buy trade stop loss level, close 
							{
								Write(logfile,"Stop Loss of Buy Order Hit at "+DoubleToStr(sl,Digits)+", Closing at "+DoubleToStr(Bid,Digits));
								if ( ! OrderClose(OrderTicket(),OrderLots(),Bid,0,Green)) {
									Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
								}
							}
							if (Bid>sl) 
							// if bid higher than sl, reset stop loss set to open minus stop loss
							{
								Write(logfile,"Stop Loss of Buy Order Reset to "+DoubleToStr(sl,Digits)+", at "+DoubleToStr(Bid,Digits));
								if ( ! OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0,Green)) {
									Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
								}
							}
						}
					}
				}
				if (OrderType()==OP_SELL) {
					be=OrderOpenPrice()-((BEPoints+BEOffset)*Point);
					if (AddSpreadToSL)
					{
						sl=OrderOpenPrice()+sp+(SL*Point);
					}
					else
					{
						sl=OrderOpenPrice()+(SL*Point);
					}
					if (BEPoints==0 || Ask>be) {
						if (osl>sl)
						// is ask higher than break-even (open - BE) and 
						// is stop loss higher than where it should be
						{
							if (Ask>sl) 
							// if ask higher than sell trade stop loss level, close
							{
								Write(logfile,"Stop Loss of Sell Order Hit at "+DoubleToStr(sl,Digits)+", Closing at "+DoubleToStr(Ask,Digits));
								if ( ! OrderClose(OrderTicket(),OrderLots(),Ask,0,Red)) {
									Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
								}
							}
							if (Ask<sl) 
							// if ask lower than sl reset stop loss set to open plus stop loss
							{ 
								Write(logfile,"Stop Loss of Sell Order Reset to "+DoubleToStr(sl,Digits)+", at "+DoubleToStr(Ask,Digits));
								if ( ! OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0,Red)) {
									Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
								}
							}
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
	int slippage;
	double otp,tp;
	for (int i=OrdersTotal()-1; i>=0; i--) {
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
			if ((OrderSymbol()==Symbol()) && (OrderMagicNumber()==Magic)) { // only look if mygrid and symbol...
				otp=OrderTakeProfit();
				if (OrderType()==OP_BUY) {
					tp=OrderOpenPrice()+(TP*Point);
					slippage=NormalizeDouble((tp - otp)/Point,0); // slippage is how far Take Profit is out by
					if (slippage>0) { //output slippage to log
						Write(logfile,"Slippage of Buy Order was "+slippage);
					}
					if (otp<tp || otp>tp) 
					// is take profit other than where it should be
					{
						if (Bid>tp)
						// if bid higher than buy take profit level, close
						{
							Write(logfile,"Take Profit of Buy Order Hit at "+DoubleToStr(tp,Digits)+", Closing at "+DoubleToStr(Bid,Digits));
							if ( ! OrderClose(OrderTicket(),OrderLots(),Bid,0,Green)) {
								Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
							}
						}
						if (Bid<tp) 
						// if bid lower than tp, reset take profit to open plus take profit setting
						{
							Write(logfile,"Take Profit of Buy Order Reset to "+DoubleToStr(tp,Digits)+", at "+DoubleToStr(Bid,Digits));
							if ( ! OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),tp,0,Green)) {
								Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
							}
						}
					}
				}
				if (OrderType()==OP_SELL) {
					tp=OrderOpenPrice() - (TP * Point);
					slippage=NormalizeDouble((otp-tp)/Point,0); // slippage is how far Take Profit is out by
					if (slippage>0) { //output slippage to log
						Write(logfile,"Slippage of Sell Order was "+slippage);
					}					
					if (otp<tp || otp>tp)
					// is take profit other than where it should be
					{
						if (Ask<tp) 
						// if ask lower than sell take profit level, close
						{
							Write(logfile,"Take Profit of Sell Order Hit at "+DoubleToStr(tp,Digits)+", Closing at "+DoubleToStr(Ask,Digits));
							if ( ! OrderClose(OrderTicket(),OrderLots(),Ask,0,Red)) {
								Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
							}
						}
						if (Ask>tp) 
						// if ask higher than sl, reset take profit set to open minus take profit setting
						{ 
							Write(logfile,"Take Profit of Sell Order Reset to "+DoubleToStr(tp,Digits)+", at "+DoubleToStr(Ask,Digits));
							if ( ! OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),tp,0,Red)) {
								Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
							}
						}
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
	double osl,be,of;
	for (int i=OrdersTotal()-1; i>=0; i--) {
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
			if (OrderSymbol()==Symbol() && OrderMagicNumber()==Magic) { // only look if mygrid and symbol...
				osl=OrderStopLoss();
				if (OrderType()==OP_BUY) {
					be=OrderOpenPrice()+((BEPoints+BEOffset)*Point);
					of=OrderOpenPrice()+(BEOffset*Point);
					if (NormalizeDouble(osl,Digits)<NormalizeDouble(of,Digits) || osl==0)
					// is stop loss lower than open plus BE offset
					{
						if (Bid>be) 
						// is bid higher than break-even (open + BE)
						{
							Write(logfile,"Break Even of Buy Order set to "+DoubleToStr(of,Digits)+" at "+DoubleToStr(Bid,Digits));
							if ( ! OrderModify(OrderTicket(),OrderOpenPrice(),of,OrderTakeProfit(),0,Green)) {
								Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
							}
						}
						if (Bid<osl && osl!=0)
						// if bid lower than buy trade stop loss level, close 
						{
							Write(logfile,"Stop Loss of Buy Order Hit at "+DoubleToStr(osl,Digits)+", Closing at "+DoubleToStr(Bid,Digits));
							if ( ! OrderClose(OrderTicket(),OrderLots(),Bid,0,Green)) {
								Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
							}
						}
					}
				}
				if (OrderType()==OP_SELL) {
					be=OrderOpenPrice()-((BEPoints+BEOffset)*Point);
					of=OrderOpenPrice()-(BEOffset*Point);
					if (NormalizeDouble(osl,Digits)>NormalizeDouble(of,Digits) || osl==0)
					// is stop loss higher than open minus BE offset
					{
						if (Ask<be)
						// is ask lower than break-even (open - BE)
						{
							Write(logfile,"Break Even of Sell Order set to "+DoubleToStr(of,Digits)+" at "+DoubleToStr(Ask,Digits));
							if ( ! OrderModify(OrderTicket(),OrderOpenPrice(),of,OrderTakeProfit(),0,Red)) {
								Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
							}
						}
						if (Ask>osl && osl!=0) 
						// if ask higher than sell trade stop loss level, close
						{
							Write(logfile,"Stop Loss of Sell Order Hit at "+DoubleToStr(osl,Digits)+", Closing at "+DoubleToStr(Ask,Digits));
							if ( ! OrderClose(OrderTicket(),OrderLots(),Ask,0,Red)) {
								Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
							}
						}
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
	double osl,to,tl;
	for (int i=OrdersTotal()-1; i>=0; i--) {
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
			if (OrderSymbol()==Symbol() && OrderMagicNumber()==Magic) { // only look if mygrid and symbol...
				osl=OrderStopLoss();
				if (OrderType()==OP_BUY) {
					to=OrderOpenPrice()+((TrailPoints+TrailOffset)*Point);
					tl=Bid-(TrailPoints*Point);
					if ((!TrailImmediate && Bid>to) || TrailImmediate) 
					// is bid higher than open plus trail and offset setting or is TrailImmediate=true
					{
						if (NormalizeDouble(osl,Digits)<NormalizeDouble(tl,Digits) || osl==0)
						// is stop loss less than bid minus the trail setting
						{
							Write(logfile,"Trailing Stop of Buy Order set to "+DoubleToStr(tl,Digits)+" at "+DoubleToStr(Bid,Digits));
							if ( ! OrderModify(OrderTicket(),OrderOpenPrice(),tl,OrderTakeProfit(),0,Green)) {
								Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
							}
						}
					}
					if (Bid<osl && osl!=0)
					// if bid lower than buy stop level, close 
					{
						Write(logfile,"Stop Loss of Buy Order Hit at "+DoubleToStr(osl,Digits)+", Closing at "+DoubleToStr(Bid,Digits));
						if ( ! OrderClose(OrderTicket(),OrderLots(),Bid,0,Green)) {
							Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
						}
					}
				}
				if (OrderType()==OP_SELL) {
					to=OrderOpenPrice()-((TrailPoints+TrailOffset)*Point);
					tl=Ask+(TrailPoints*Point);
					if ((!TrailImmediate && Ask<to) || TrailImmediate) 
					// is ask lower than open minus trail and offset setting or is TrailImmediate=true
					{
						if (NormalizeDouble(osl,Digits)>NormalizeDouble(tl,Digits) || osl==0)
						// is stop loss higher than ask plus the trail setting
						{
							Write(logfile,"Trailing Stop of Sell Order set to "+DoubleToStr(tl,Digits)+" at "+DoubleToStr(Ask,Digits));
							if ( ! OrderModify(OrderTicket(),OrderOpenPrice(),tl,OrderTakeProfit(),0,Red)) {
								Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
							}
						}
					}
					if (Ask>osl && osl!=0) 
					// if ask higher than sell stop level, close
					{
						Write(logfile,"Stop Loss of Sell Order Hit at "+DoubleToStr(osl,Digits)+", Closing at "+DoubleToStr(Ask,Digits));
						if ( ! OrderClose(OrderTicket(),OrderLots(),Ask,0,Red)) {
							Write(logfile,"Error Occurred : "+ErrorDescription(GetLastError()));
						}
					}
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
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
			if (OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==OP_BUYSTOP) {
				if ( ! OrderDelete(OrderTicket())) {
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
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) { 
			if (OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==OP_SELLSTOP) {
				if ( ! OrderDelete(OrderTicket())) {
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
int Write(string filename, string str)
{
	ResetLastError();
	int filehandle;
	filehandle = FileOpen(filename,FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_CSV,"/t");
	if(filehandle!=INVALID_HANDLE)
	{
		FileSeek(filehandle, 0, SEEK_END); 
		FileWrite(filehandle, TimeToStr(CurTime(),TIME_DATE|TIME_SECONDS) + " " + str);
		FileClose(filehandle);
	}
	else Print("Error Occurred : "+ErrorDescription(GetLastError()));
	return(0);
}

//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int init()
{
	//ObjectsDeleteAll();
	Magic=(NHour*10000)+(NMin*100)+NSec; //Unique EA identifier
	logfile = TradeLog + "-Log-" + Symbol() + "-" + AddLeadingZero(TimeYear(TimeCurrent()),4) + "-" + AddLeadingZero(TimeMonth(TimeCurrent()),2) + "-" +  AddLeadingZero(TimeDay(TimeCurrent()),2) +  ".log";
	Print(logfile);
	tickfile = TradeLog + "-Ticks-" + Symbol() + "-" + AddLeadingZero(TimeYear(TimeCurrent()),4) + "-" +  AddLeadingZero(TimeMonth(TimeCurrent()),2) + "-" +  AddLeadingZero(TimeDay(TimeCurrent()),2) +  ".csv";
	Print(tickfile);

	MinStopLevel=MarketInfo(Symbol(),MODE_STOPLEVEL); // Min. distance for Stops

	if (ModifyGap>20) { 
		ModifyGap = 20 ; 
	}

	if (SL!=0 && SL<MinStopLevel) { 
		SL = MinStopLevel ; 
	}

	if (TP!=0 && TP<MinStopLevel) { 
		TP = MinStopLevel ; 
	}

	if (TrailPoints!=0 && TrailPoints<MinStopLevel) { 
		TrailPoints = MinStopLevel ; 
	}

	if (BEPoints!=0 && BEPoints<MinStopLevel) { 
		BEPoints = MinStopLevel ; 
	}

	return(0);
}

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                 |
//+------------------------------------------------------------------+
int deinit()
{
	if (DeleteOnShutdown) {
		Comment("");
		Write(logfile,"Amazing EA shut down");
		OrdersDeleteAll();
	}
	return(0);
}

//+------------------------------------------------------------------+
//| Expert Start Function                                            |
//+------------------------------------------------------------------+
int start()
{

	sp=Ask-Bid;
	int spread=NormalizeDouble(sp/Point,Digits);
	Write(tickfile,","+DoubleToStr(Bid,Digits)+","+DoubleToStr(Ask,Digits)+","+spread);

	int secofday,secofnews;
	string brokertime;
	int OrdersCondition=CheckOrdersCondition();

	if (OrdersCondition>11) { // we have open trades, amending stops
		if (SlipCheck && SL!=0 && TP!=0) DoSlip(); // SL and TP both set, reset both and work out slippage
		if (SlipCheck && SL!=0 && TP==0) DoSL(); // SL set so can reset SL, TP not set so can't workout slippage
		if (SlipCheck && SL==0 && TP!=0) DoTP(); // TP set but no SL, no point working out slippage
		if (TrailPoints!=0) DoTrail(); // perform trailing stop processing
		if (BEPoints!=0) DoBE(); // perform break even processing
	}

	if (UseBrokerTime) {
		secofday=TimeHour(TimeCurrent())*3600+TimeMinute(TimeCurrent())*60+TimeSeconds(TimeCurrent());
		brokertime=TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS); // BrokerTime is shown in the EA Comment.
	}
	else
	{
		secofday=TimeHour(TimeLocal())*3600+TimeMinute(TimeLocal())*60+TimeSeconds(TimeLocal());
		brokertime=TimeToStr(TimeLocal(),TIME_DATE|TIME_SECONDS); // BrokerTime is shown in the EA Comment.
	}

	secofnews=NHour*3600+NMin*60+NSec;

	if (SecBPO!=SecBAO && SecBAO!=0 && PointsAway<PointsGap) {
		if (secofday<secofnews && secofday>(secofnews-SecBPO) && secofday<(secofnews-SecBAO)) 
		{ // if before news but after (news minus BPO) and before (news minus BAO)
			{
				PointsAway=PointsAway+PointsGap;
			}
		}
	}

	if (SecBPO!=SecBAO && SecBAO!=0 && PointsAway>=PointsGap) {
		if (secofday<secofnews && secofday>(secofnews-SecBPO) && secofday>=(secofnews-SecBAO)) 
		{ // if before news but after (news minus BPO) and after (news minus BAO)
			{
				PointsAway=PointsAway-PointsGap;
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
		h=iHigh(NULL,0,0);
		l=iLow(NULL,0,0);
		int i;
		for (i=1;i<=CTCBN;i++) if (iHigh(NULL,0,i-1)>h) h=iHigh(NULL,0,i-1);
		for (i=1;i<=CTCBN;i++) if (iLow(NULL,0,i-1)<l) l=iLow(NULL,0,i-1);
	}

	ho=h+sp+(PointsAway*Point); 
	if (ho < Ask+(MinStopLevel*Point)) ho=Ask+(MinStopLevel*Point); //Ensure orders are MinStopLevel away but only if necessary
	lo=l-(PointsAway*Point);
	if (lo > Bid-(MinStopLevel*Point)) lo=Bid-(MinStopLevel*Point); //Ensure orders are MinStopLevel away but only if necessary

	if (SL==0)
	{
		hso = 0;
		lso = 0;
	}
	else if (AddSpreadToSL)
	{
		hso=ho-sp-(SL*Point); //Bid+(PointsAway*Point)-(SL*Point); //hso=Ask+(PipsAway-SL)*Point; //hso=h+sp;
		lso=lo+sp+(SL*Point); //Ask-(PointsAway*Point)+(SL*Point); //lso=Bid-(PipsAway-SL)*Point; //lso=l;
	}
	else
	{
		hso=ho-(SL*Point); //Ask+(PointsAway*Point)-(SL*Point)
		lso=lo+(SL*Point); //Bid-(PointsAway*Point)+(SL*Point)
	}

	if (TP==0)
	{
		htp = 0;
		ltp = 0;
	}
	else
	{ 
		htp=ho+(TP*Point);
		ltp=lo-(TP*Point);
	}

	string title="Amazing Forex System Expert Advisor (MT4) v5.20 By Alan Prothero";
	string newstime=StringConcatenate(AddLeadingZero(NYear,4),".",AddLeadingZero(NMonth,2),".",AddLeadingZero(NDay,2)," ",TimeToStr(secofnews,TIME_SECONDS));
	string timetitle=StringConcatenate("System Time : ", brokertime, "\nNews Time    : ", newstime);
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
	string Comment1=StringConcatenate("High @ ",DoubleToStr(h,Digits)," BuyOrder @ ",DoubleToStr(ho,Digits)," StopLoss @ ",DoubleToStr(hso,Digits)," TakeProfit @ ",DoubleToStr(htp,Digits));
	string Comment2=StringConcatenate("Low  @ ",DoubleToStr(l,Digits)," SellOrder @ ",DoubleToStr(lo,Digits)," StopLoss @ ",DoubleToStr(lso,Digits)," TakeProfit @ ",DoubleToStr(ltp,Digits));
	string Comment3=StringConcatenate("PointsAway : ",PointsAway," | PointsGap : ",PointsGap," | ModifyGap : ",ModifyGap);
	string Comment4=StringConcatenate("BEOffset : ",BEOffset," | BEPoints : ",BEPoints," | TrailOffset : ", TrailOffset," | TrailPoints : ", TrailPoints);
	string Comment5=StringConcatenate("CTCBN : ",CTCBN," | SecBPO : ",SecBPO," | SecBAO : ",SecBAO," | SecBMO : ",SecBMO," | STWAN : ",STWAN," | OCO : ",DisplayOCO);
	string Comment6=StringConcatenate("Money Management : ",DisplayMM," | RiskPercent: ",RiskPercent," | Lots : ",LotsOptimized());
	string Comment7=StringConcatenate("AddSpreadToSL : ",DisplayAddSpreadToSL," | SlipCheck : ",DisplaySlipCheck," | TrailImmediate : ",DisplayTrailImmediate);
	string Comment8=StringConcatenate("MaxSlippage : ",MaxSlippage," | MaxSpread : ",MaxSpread," | Spread : ",spread);
	string Comment9=StringConcatenate("AllowBuys : ",DisplayAllowBuys," | AllowSells : ",DisplayAllowSells);
	string CommentA=StringConcatenate("UseBrokerTime : ",DisplayUseBrokerTime," | DeleteOnShutdown : ",DisplayDeleteOnShutdown);
	
	// TradeComment gets added in the Comment field of trades. Max 32 chars.
	if (PointsAway>=PointsGap) 
	{ 
		TradeComment=StringConcatenate("P", PointsAway-PointsGap, "T", TP, "S", SL, "C", CTCBN, "P", SecBPO, "A", SecBAO, "M", SecBMO, "W", STWAN, "O", OCO, "B", BEPoints, "T", TrailPoints);
	}
	else
	{
		TradeComment=StringConcatenate("P", PointsAway, "T", TP, "S", SL, "C", CTCBN, "P", SecBPO, "A", SecBAO, "M", SecBMO, "W", STWAN, "O", OCO, "B", BEPoints, "T", TrailPoints );
	}

	if (MaxSpread!=0)
	{
		if (spread>MaxSpread) {
			Write(logfile,"MaxSpread Exceeded, MaxSpread: "+MaxSpread+" Spread : "+spread);
			OrdersDeleteAll();
			Comment("\n",title,"\n\n",timetitle,"\n\n","MaxSpread : ",MaxSpread," | Spread : ",spread,"\n\n","Expert is disabled because Spread exceeds MaxSpread Setting");
			// Despite the comment above, the expert is not really disabled, it just exits without trading.
			// The return statement below is very important as it ensures the EA exits without opening trades if the Spread is too high.
			Sleep(5000); // Suspend for 5 seconds
			return (0);
		}
	}

	if ((!UseBrokerTime && NYear==TimeYear(TimeLocal()) && NMonth==TimeMonth(TimeLocal()) && NDay==TimeDay(TimeLocal())) || (UseBrokerTime && NYear==TimeYear(TimeCurrent()) && NMonth==TimeMonth(TimeCurrent()) && NDay==TimeDay(TimeCurrent())) || (NYear==0 && NMonth==0 && NDay==0))
	{
		Comment("\n",title,"\n\n",timetitle,"\n\n",Comment1,"\n", Comment2,"\n\n", Comment3,"\n\n",Comment4,"\n\n",Comment5,"\n\n",Comment6,"\n\n",Comment7,"\n\n",Comment8,"\n\n",Comment9,"\n\n",CommentA);
	}
	else
	{
		Comment("\n",title,"\n\n",timetitle,"\n\n","Expert is disabled because it is not day of expected news");
		// Despite the comment above, the expert is not really disabled, it just exits without trading.
		// The return statement below is very important as it ensures the EA exits without opening trades on non-news days. 
		return(0);
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
				Write(logfile,"Opening BuyStop @ "+DoubleToStr(ho,Digits)+", OrdersCondition="+OrdersCondition);
				OpenBuyStop();
			}
			if (AllowSells) { // if sells are allowed
				Write(logfile,"Opening SellStop @ "+DoubleToStr(lo,Digits)+", OrdersCondition="+OrdersCondition);
				OpenSellStop();
			}
		}
		if (OrdersCondition==1 && AllowBuys) { // if we only have a sell stop and buys are allowed
			Write(logfile,"Opening BuyStop @ "+DoubleToStr(ho,Digits)+", OrdersCondition="+OrdersCondition);
			OpenBuyStop();
		}
		if (OrdersCondition==10 && AllowSells) { // if we only have a buy stop and sells are allowed
			Write(logfile,"Opening SellStop @ "+DoubleToStr(lo,Digits)+", OrdersCondition="+OrdersCondition);
			OpenSellStop();
		}
	}

	if (secofday<(secofnews+STWAN) && secofday>(secofnews-SecBPO) && (secofday>(secofnews-SecBAO)||PointsGap==0||SecBAO==0) && secofday<(secofnews-SecBMO)) 
	{ // if before STWAN but after news minus BPO and after news minus BAO and before news minus BMO (allows negative BMO)
		// if PointsGap is 0, or SecBAO is 0, then SecBAO is ignored
		Write(logfile,"Modifying Orders, OrdersCondition="+OrdersCondition);
		DoModify();
	}

	if (secofday>secofnews && secofday<(secofnews+STWAN) && OCO) 
	{ // if after news and within wait time and we are using one cancels other
		if (OrdersCondition==1001) { // if we have a buy and a sell stop
			Write(logfile,"Deleting SellStop because BuyStop Hit, OrdersCondition="+OrdersCondition);
			DeleteSellStop();
		}
		if (OrdersCondition==110) { // if we have a sell and a buy stop
			Write(logfile,"Deleting BuyStop because SellStop Hit, OrdersCondition="+OrdersCondition);
			DeleteBuyStop();
		}
	}

	if (secofday>secofnews && secofday>(secofnews+STWAN)) 
	{ // if after news and after wait time 
		if (OrdersCondition==11) { // if we have a buy stop and a sell stop
			Write(logfile,"Deleting BuyStop and SellStop because STWAN expired, OrdersCondition="+OrdersCondition);
			DeleteSellStop();
			DeleteBuyStop();
		}
		if (OrdersCondition==1 || OrdersCondition==1001) { // if we have a sell stop or a buy and a sell stop
			Write(logfile,"Deleting SellStop because STWAN expired, OrdersCondition="+OrdersCondition);
			DeleteSellStop();
		}
		if (OrdersCondition==10 || OrdersCondition==110) { // if we have a buy stop or a sell and a buy stop
			Write(logfile,"Deleting BuyStop because STWAN expired, OrdersCondition="+OrdersCondition);
			DeleteBuyStop();
		}
	}

	//----
	return(0);
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
	case 0   : error_string="No error returned";                                                                              break;
	case 1   : error_string="No error returned, but the result is unknown";                                                   break;
	case 2   : error_string="Common error";                                                                                   break;
	case 3   : error_string="Invalid trade parameters";                                                                       break;
	case 4   : error_string="Trade server is busy";                                                                           break;
	case 5   : error_string="Old version of the client terminal";                                                             break;
	case 6   : error_string="No connection with trade server";                                                                break;
	case 7   : error_string="Not enough rights";                                                                              break;
	case 8   : error_string="Too frequent requests";                                                                          break;
	case 9   : error_string="Malfunctional trade operation";                                                                  break;
	case 64  : error_string="Account disabled";                                                                               break;
	case 65  : error_string="Invalid account";                                                                                break;
	case 128 : error_string="Trade timeout";                                                                                  break;
	case 129 : error_string="Invalid price";                                                                                  break;
	case 130 : error_string="Invalid stops";                                                                                  break;
	case 131 : error_string="Invalid trade volume";                                                                           break;
	case 132 : error_string="Market is closed";                                                                               break;
	case 133 : error_string="Trade is disabled";                                                                              break;
	case 134 : error_string="Not enough money";                                                                               break;
	case 135 : error_string="Price changed";                                                                                  break;
	case 136 : error_string="Off quotes";                                                                                     break;
	case 137 : error_string="Broker is busy";                                                                                 break;
	case 138 : error_string="Requote";                                                                                        break;
	case 139 : error_string="Order is locked";                                                                                break;
	case 140 : error_string="Buy orders only allowed";                                                                        break;
	case 141 : error_string="Too many requests";                                                                              break;
	case 145 : error_string="Modification denied because order is too close to market";                                       break;
	case 146 : error_string="Trade context is busy";                                                                          break;
	case 147 : error_string="Expirations are denied by broker";                                                               break;
	case 148 : error_string="The amount of open and pending orders has reached the limit set by the broker";                  break;
	case 149 : error_string="An attempt to open an order opposite to the existing one when hedging is disabled";              break;
	case 150 : error_string="An attempt to close an order contravening the FIFO rule";                                        break;
		//---- MQL Errors
	case 4000: error_string="No error returned";                                                                              break;
	case 4001: error_string="Wrong function pointer";                                                                         break;
	case 4002: error_string="Array index is out of range";                                                                    break;
	case 4003: error_string="No memory for function call stack";                                                              break;
	case 4004: error_string="Recursive stack overflow";                                                                       break;
	case 4005: error_string="Not enough stack for parameter";                                                                 break;
	case 4006: error_string="No memory for parameter string";                                                                 break;
	case 4007: error_string="No memory for temp string";                                                                      break;
	case 4008: error_string="Not initialized string";                                                                         break;
	case 4009: error_string="Not initialized string in array";                                                                break;
	case 4010: error_string="No memory for array string";                                                                     break;
	case 4011: error_string="Too long string";                                                                                break;
	case 4012: error_string="Remainder from zero divide";                                                                     break;
	case 4013: error_string="Zero divide";                                                                                    break;
	case 4014: error_string="Unknown command";                                                                                break;
	case 4015: error_string="Wrong jump (never generated error)";                                                             break;
	case 4016: error_string="Not initialized array";                                                                          break;
	case 4017: error_string="DLL calls are not allowed";                                                                      break;
	case 4018: error_string="Cannot load library";                                                                            break;
	case 4019: error_string="Cannot call function";                                                                           break;
	case 4020: error_string="Expert function calls are not allowed";                                                          break;
	case 4021: error_string="Not enough memory for temp string returned from function";                                       break;
	case 4022: error_string="System is busy (never generated error)";                                                         break;
	case 4023: error_string="DLL-function call critical error";                                                               break;
	case 4024: error_string="Internal error";                                                                                 break;
	case 4025: error_string="Out of memory";                                                                                  break;
	case 4026: error_string="Invalid pointer";                                                                                break;
	case 4027: error_string="Too many formatters in the format function";                                                     break;
	case 4028: error_string="Parameters count exceeds formatters count";                                                      break;
	case 4029: error_string="Invalid array";                                                                                  break;
	case 4030: error_string="No reply from chart";                                                                            break;
	case 4050: error_string="Invalid function parameters count";                                                              break;
	case 4051: error_string="Invalid function parameter value";                                                               break;
	case 4052: error_string="String function internal error";                                                                 break;
	case 4053: error_string="Some array error";                                                                               break;
	case 4054: error_string="Incorrect series array using";                                                                   break;
	case 4055: error_string="Custom indicator error";                                                                         break;
	case 4056: error_string="Arrays are incompatible";                                                                        break;
	case 4057: error_string="Global variables processing error";                                                              break;
	case 4058: error_string="Global variable not found";                                                                      break;
	case 4059: error_string="Function is not allowed in testing mode";                                                        break;
	case 4060: error_string="Function is not allowed for call";                                                               break;
	case 4061: error_string="Send mail error";                                                                                break;
	case 4062: error_string="String parameter expected";                                                                      break;
	case 4063: error_string="Integer parameter expected";                                                                     break;
	case 4064: error_string="Double parameter expected";                                                                      break;
	case 4065: error_string="Array as parameter expected";                                                                    break;
	case 4066: error_string="Requested history data is in updating state";                                                    break;
	case 4067: error_string="Internal trade error";                                                                           break;
	case 4068: error_string="Resource not found";                                                                             break;
	case 4069: error_string="Resource not supported";                                                                         break;
	case 4070: error_string="Duplicate resource";                                                                             break;
	case 4071: error_string="Custom indicator cannot initialize";                                                             break;
	case 4072: error_string="Cannot load custom indicator";                                                                   break;
	case 4099: error_string="End of file";                                                                                    break;
	case 4100: error_string="Some file error";                                                                                break;
	case 4101: error_string="Wrong file name";                                                                                break;
	case 4102: error_string="Too many opened files";                                                                          break;
	case 4103: error_string="Cannot open file";                                                                               break;
	case 4104: error_string="Incompatible access to a file";                                                                  break;
	case 4105: error_string="No order selected";                                                                              break;
	case 4106: error_string="Unknown symbol";                                                                                 break;
	case 4107: error_string="Invalid price";                                                                                  break;
	case 4108: error_string="Invalid ticket";                                                                                 break;
	case 4109: error_string="Trade is not allowed. Enable checkbox Allow live trading in the Expert Advisor properties";      break;
	case 4110: error_string="Longs are not allowed. Check the Expert Advisor properties";                                     break;
	case 4111: error_string="Shorts are not allowed. Check the Expert Advisor properties";                                    break;
	case 4112: error_string="Automated trading by Expert Advisors/Scripts disabled by trade server";                          break;
	case 4200: error_string="Object already exists";                                                                          break;
	case 4201: error_string="Unknown object property";                                                                        break;
	case 4202: error_string="Object does not exist";                                                                          break;
	case 4203: error_string="Unknown object type";                                                                            break;
	case 4204: error_string="No object name";                                                                                 break;
	case 4205: error_string="Object coordinates error";                                                                       break;
	case 4206: error_string="No specified subwindow";                                                                         break;
	case 4207: error_string="Graphical object error";                                                                         break;
	case 4210: error_string="Unknown chart property";                                                                         break;
	case 4211: error_string="Chart not found";                                                                                break;
	case 4212: error_string="Chart subwindow not found";                                                                      break;
	case 4213: error_string="Chart indicator not found";                                                                      break;
	case 4220: error_string="Symbol select error";                                                                            break;
	case 4250: error_string="Notification error";                                                                             break;
	case 4251: error_string="Notification parameter error";                                                                   break;
	case 4252: error_string="Notifications disabled";                                                                         break;
	case 4253: error_string="Notification send too frequent";                                                                 break;
	case 5001: error_string="Too many opened files";                                                                          break;
	case 5002: error_string="Wrong file name";                                                                                break;
	case 5003: error_string="Too long file name";                                                                             break;
	case 5004: error_string="Cannot open file";                                                                               break;
	case 5005: error_string="Text file buffer allocation error";                                                              break;
	case 5006: error_string="Cannot delete file";                                                                             break;
	case 5007: error_string="Invalid file handle (file closed or was not opened)";                                            break;
	case 5008: error_string="Wrong file handle (handle index is out of handle table)";                                        break;
	case 5009: error_string="File must be opened with FILE_WRITE flag";                                                       break;
	case 5010: error_string="File must be opened with FILE_READ flag";                                                        break;
	case 5011: error_string="File must be opened with FILE_BIN flag";                                                         break;
	case 5012: error_string="File must be opened with FILE_TXT flag";                                                         break;
	case 5013: error_string="File must be opened with FILE_TXT or FILE_CSV flag";                                             break;
	case 5014: error_string="File must be opened with FILE_CSV flag";                                                         break;
	case 5015: error_string="File read error";                                                                                break;
	case 5016: error_string="File write error";                                                                               break;
	case 5017: error_string="String size must be specified for binary file";                                                  break;
	case 5018: error_string="Incompatible file (for string arrays-TXT, for others-BIN)";                                      break;
	case 5019: error_string="File is directory not file";                                                                     break;
	case 5020: error_string="File does not exist";                                                                            break;
	case 5021: error_string="File cannot be rewritten";                                                                       break;
	case 5022: error_string="Wrong directory name";                                                                           break;
	case 5023: error_string="Directory does not exist";                                                                       break;
	case 5024: error_string="Specified file is not directory";                                                                break;
	case 5025: error_string="Cannot delete directory";                                                                        break;
	case 5026: error_string="Cannot clean directory";                                                                         break;
	case 5027: error_string="Array resize error";                                                                             break;
	case 5028: error_string="String resize error";                                                                            break;
	case 5029: error_string="Structure contains strings or dynamic arrays";                                                   break;
	case 5200: error_string="Invalid URL";                                                                                    break;
	case 5201: error_string="Failed to connect to specified URL";                                                             break;
	case 5202: error_string="Timeout exceeded";                                                                               break;
	case 5203: error_string="HTTP request failed";                                                                            break;
	default:   error_string="Unknown Error";
	}
	//----
	return(error_string);
}  
//+------------------------------------------------------------------+
