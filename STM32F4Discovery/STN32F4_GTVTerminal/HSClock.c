
/* Includes ------------------------------------------------------------------*/
#include "HSClock.h"

/* External variables --------------------------------------------------------*/
extern volatile uint16_t FrameCount;
extern WINDOW* Focus;                 // The control that has the keyboard focus
extern volatile uint8_t Caps;
extern volatile uint8_t Num;
extern uint8_t FrameBuff[SCREEN_BUFFHEIGHT][SCREEN_BUFFWIDTH];
extern uint32_t frequency;

/* Private variables ---------------------------------------------------------*/
HSCLK HSClk;
//uint8_t scopestr[9][6]={{"Ofs:"},{"Mrk:"},{"Pos:"},{"Frq:"},{"Tme:"},{"Vcu:"},{"Vpp:"},{"Vmn:"},{"Vmx:"}};

/* Private function prototypes -----------------------------------------------*/
/* Private functions ---------------------------------------------------------*/

void HSClkMainHandler(WINDOW* hwin,uint8_t event,uint32_t param,uint8_t ID)
{
  switch (event)
  {
    case EVENT_CHAR:
      if (param==0x0D)
      {
        switch (ID)
        {
          case 1:
            /* Fast left */
            // Scope.dataofs-=256;
            // if (Scope.dataofs<0)
            // {
              // Scope.dataofs=0;
            // }
            // Scope.tmrid=ID;
            break;
          case 2:
            /* Fast right */
            // Scope.dataofs+=256;
            // if (Scope.dataofs>SCOPE_DATASIZE-256)
            // {
              // Scope.dataofs=SCOPE_DATASIZE-256;
            // }
            // Scope.tmrid=ID;
            break;
          case 3:
            /* Left */
            // Scope.dataofs--;
            // if (Scope.dataofs<0)
            // {
              // Scope.dataofs=0;
            // }
            // Scope.tmrid=ID;
            break;
          case 4:
            /* Right */
            // Scope.dataofs++;
            // if (Scope.dataofs>SCOPE_DATASIZE-256)
            // {
              // Scope.dataofs=SCOPE_DATASIZE-256;
            // }
            // Scope.tmrid=ID;
            break;
          case 98:
            /* Sample */
            // Scope.Sample=1;
            break;
          case 99:
            /* Quit */
            HSClk.Quit=1;
            break;
        }
      }
    case EVENT_LUP:
      // Scope.tmrid=0;
      // Scope.tmrmax=32;
      // Scope.tmrcnt=0;
      break;
    default:
      DefWindowHandler(hwin,event,param,ID);
      break;
  }
}

void HSClkHandler(WINDOW* hwin,uint8_t event,uint32_t param,uint8_t ID)
{
  uint16_t x;

  switch (event)
  {
    case EVENT_PAINT:
      DefWindowHandler(hwin,event,param,ID);
      // if (FrameCount & 1)
      // {
        // ScopeDrawGrid();
      // }
      // ScopeDrawMark();
      // ScopeDrawData();
      // ScopeDrawInfo();
      break;
    case EVENT_LDOWN:
      // x=param & 0xFFFF;
      // Scope.mark=x+Scope.dataofs;
      break;
    case EVENT_MOVE:
      // x=param & 0xFFFF;
      // Scope.cur=x+Scope.dataofs;
      break;
    default:
      DefWindowHandler(hwin,event,param,ID);
      break;
  }
}

void HSClkDrawHLine(uint16_t x,uint16_t y,int16_t wdt)
{
  while (wdt>=0)
  {
    SetFBPixel(x,y);
    x+=2;
    wdt-=2;
  }
}

void HSClkDrawVLine(uint16_t x,uint16_t y,int16_t hgt)
{
  while (hgt>=0)
  {
    SetFBPixel(x,y);
    y+=2;
    hgt-=2;
  }
}

void HSClkDrawGrid(void)
{
  int16_t y=HSCLK_TOP+16;
  int16_t x=HSCLK_LEFT+32;

  while (y<=HSCLK_BOTTOM-30)
  {
    HSClkDrawHLine(HSCLK_LEFT,y,HSCLK_WIDTH);
    y+=16;
  }
  while (x<HSCLK_WIDTH)
  {
    HSClkDrawVLine(x,HSCLK_TOP,8*16);
    x+=32;
  }
}

void HSClkDrawMark(void)
{
  uint16_t x;

  // if (Scope.markshow)
  // {
    // if ((Scope.mark>=Scope.dataofs) && (Scope.mark<Scope.dataofs+HSCLK_BYTES))
    // {
      // /* Draw mark */
      // x=Scope.mark-Scope.dataofs+SCOPE_LEFT;
      // ScopeDrawVLine(x,SCOPE_TOP,8*16);
    // }
    // if ((Scope.cur>=Scope.dataofs) && (Scope.cur<Scope.dataofs+HSCLK_BYTES))
    // {
      // /* Draw mark */
      // x=Scope.cur-Scope.dataofs+SCOPE_LEFT;
      // ScopeDrawVLine(x,SCOPE_TOP,8*16);
    // }
  // }
}

void HSClkDrawData(void)
{
}

void HSClkDrawInfo(void)
{
  // /* Offset */
  // DrawWinString(SCOPE_LEFT+4,SCOPE_BOTTOM-30,4,scopestr[0],1);
  // /* Mark */
  // DrawWinString(SCOPE_LEFT+4,SCOPE_BOTTOM-20,4,scopestr[1],1);
  // /* Position */
  // DrawWinString(SCOPE_LEFT+4,SCOPE_BOTTOM-10,4,scopestr[2],1);

  // /* Frequency */
  // DrawWinString(SCOPE_LEFT+4+9*8,SCOPE_BOTTOM-30,4,scopestr[3],1);
  // DrawWinDec32(SCOPE_LEFT+4+14*8,SCOPE_BOTTOM-30,frequency,5);
  // /* Time */
  // DrawWinString(SCOPE_LEFT+4+9*8,SCOPE_BOTTOM-20,4,scopestr[4],1);
  // /* Vcurrent */
  // DrawWinString(SCOPE_LEFT+4+9*8,SCOPE_BOTTOM-10,4,scopestr[5],1);
}

void HSClkSetup(void)
{
  uint32_t i;
  WINDOW* hwin;
  uint8_t caps,num;

  Cls();
  ShowCursor(1);
  HSClk.Quit=0;
  /* Create main HSClk window */
  HSClk.hmain=CreateWindow(0,CLASS_WINDOW,0,HSCLK_MAINLEFT,HSCLK_MAINTOP,HSCLK_MAINWIDTH,HSCLK_MAINHEIGHT,"High Speed Clock\0");
  SetHandler(HSClk.hmain,&HSClkMainHandler);
  // /* Sample button */
  // CreateWindow(Scope.hmain,CLASS_BUTTON,98,SCOPE_MAINRIGHT-75-75,SCOPE_MAINBOTTOM-25,70,20,"Sample\0");
  /* Quit button */
  CreateWindow(HSClk.hmain,CLASS_BUTTON,99,HSCLK_MAINRIGHT-75,HSCLK_MAINBOTTOM-25,70,20,"Quit\0");
  // /* Fast left button */
  // CreateWindow(Scope.hmain,CLASS_BUTTON,1,SCOPE_LEFT,SCOPE_BOTTOM,20,20,"<<\0");
  // /* Left button */
  // CreateWindow(Scope.hmain,CLASS_BUTTON,3,SCOPE_LEFT+20,SCOPE_BOTTOM,20,20,"<\0");
  // /* Right button */
  // CreateWindow(Scope.hmain,CLASS_BUTTON,4,SCOPE_RIGHT-20-20,SCOPE_BOTTOM,20,20,">\0");
  // /* Fast right button */
  // CreateWindow(Scope.hmain,CLASS_BUTTON,2,SCOPE_RIGHT-20,SCOPE_BOTTOM,20,20,">>\0");

  // CreateWindow(Lga.hmain,CLASS_GROUPBOX,97,LGA_MAINRIGHT-75-75,LGA_TOP+5,145,150,"Trigger\0");

  // CreateWindow(Lga.hmain,CLASS_CHKBOX,20,LGA_MAINRIGHT-140,LGA_TOP+30,30,10,"D0\0");
  // CreateWindow(Lga.hmain,CLASS_CHKBOX,21,LGA_MAINRIGHT-140,LGA_TOP+30+15,30,10,"D1\0");
  // CreateWindow(Lga.hmain,CLASS_CHKBOX,22,LGA_MAINRIGHT-140,LGA_TOP+30+30,30,10,"D2\0");
  // CreateWindow(Lga.hmain,CLASS_CHKBOX,23,LGA_MAINRIGHT-140,LGA_TOP+30+45,30,10,"D3\0");
  // CreateWindow(Lga.hmain,CLASS_CHKBOX,24,LGA_MAINRIGHT-140,LGA_TOP+30+60,30,10,"D4\0");
  // CreateWindow(Lga.hmain,CLASS_CHKBOX,25,LGA_MAINRIGHT-140,LGA_TOP+30+75,30,10,"D5\0");
  // CreateWindow(Lga.hmain,CLASS_CHKBOX,26,LGA_MAINRIGHT-140,LGA_TOP+30+90,30,10,"D6\0");
  // CreateWindow(Lga.hmain,CLASS_CHKBOX,27,LGA_MAINRIGHT-140,LGA_TOP+30+105,30,10,"D7\0");
  // i=0;
  // while (i<8)
  // {
    // SetStyle(GetControlHandle(Lga.hmain,i+20),STYLE_RIGHT | STYLE_CANFOCUS);
    // i++;
  // }
  // CreateWindow(Lga.hmain,CLASS_CHKBOX,30,LGA_MAINRIGHT-55,LGA_TOP+30,30,10,0);
  // CreateWindow(Lga.hmain,CLASS_CHKBOX,31,LGA_MAINRIGHT-55,LGA_TOP+30+15,10,10,0);
  // CreateWindow(Lga.hmain,CLASS_CHKBOX,32,LGA_MAINRIGHT-55,LGA_TOP+30+30,10,10,0);
  // CreateWindow(Lga.hmain,CLASS_CHKBOX,33,LGA_MAINRIGHT-55,LGA_TOP+30+45,10,10,0);
  // CreateWindow(Lga.hmain,CLASS_CHKBOX,34,LGA_MAINRIGHT-55,LGA_TOP+30+60,10,10,0);
  // CreateWindow(Lga.hmain,CLASS_CHKBOX,35,LGA_MAINRIGHT-55,LGA_TOP+30+75,10,10,0);
  // CreateWindow(Lga.hmain,CLASS_CHKBOX,36,LGA_MAINRIGHT-55,LGA_TOP+30+90,10,10,0);
  // CreateWindow(Lga.hmain,CLASS_CHKBOX,37,LGA_MAINRIGHT-55,LGA_TOP+30+105,10,10,0);

  // /* Rate Left button */
  // CreateWindow(Lga.hmain,CLASS_BUTTON,40,LGA_MAINRIGHT-150,LGA_MAINBOTTOM-50,20,20,"<\0");
  // /* Rate */
  // CreateWindow(Lga.hmain,CLASS_STATIC,41,LGA_MAINRIGHT-150+20,LGA_MAINBOTTOM-50,105,20,"33.6MHz\0");
  // /* Rate Right button */
  // CreateWindow(Lga.hmain,CLASS_BUTTON,42,LGA_MAINRIGHT-25,LGA_MAINBOTTOM-50,20,20,">\0");

  /* Create HSClk window */
  HSClk.hhsclk=CreateWindow(HSClk.hmain,CLASS_STATIC,1,HSCLK_LEFT,HSCLK_TOP,HSCLK_WIDTH,HSCLK_HEIGHT,0);
  SetStyle(HSClk.hhsclk,STYLE_BLACK);
  SetHandler(HSClk.hhsclk,&HSClkHandler);

  SendEvent(HSClk.hmain,EVENT_ACTIVATE,0,0);
  DrawStatus(0,Caps,Num);
  HSClk.cur=0;
  HSClk.mark=0;
  HSClk.dataofs=0;
  HSClk.tmrid=0;
  HSClk.tmrmax=32;
  HSClk.tmrcnt=0;
  CreateTimer(HSClkTimer);

  while (!HSClk.Quit)
  {
    // if (Scope.Sample)
    // {
      // Scope.Sample=0;
      // SetStyle(Scope.hmain,STATE_VISIBLE);
      // SetStyle(Scope.hmain,STYLE_LEFT);
      // LgaSample();
      // SetStyle(Scope.hmain,STYLE_LEFT | STYLE_CANFOCUS);
      // SetState(Scope.hmain,STATE_VISIBLE | STATE_FOCUS);
      // Scope.dataofs=0;
    // }
    if (caps!=Caps || num!=Num)
    {
      caps=Caps;
      num=Num;
      DrawStatus(0,caps,num);
    }
  }
  KillTimer();
  DestroyWindow(HSClk.hmain);
}

void HSClkTimer(void)
{
  if (HSClk.tmrid)
  {
    HSClk.tmrcnt++;
    if (HSClk.tmrcnt>=HSClk.tmrmax)
    {
      HSClk.tmrmax=2;
      HSClk.tmrcnt=0;
      SendEvent(HSClk.hmain,EVENT_CHAR,0x0D,HSClk.tmrid);
    }
  }
  HSClk.markcnt++;
  if (!(HSClk.markcnt & 0x0F))
  {
    HSClk.markshow^=1;
  }
}