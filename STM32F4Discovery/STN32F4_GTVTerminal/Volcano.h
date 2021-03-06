
/* Includes ------------------------------------------------------------------*/
#include "stm32f4_discovery.h"
#include "window.h"
#include "video.h"
#include "keycodes.h"

/* Private define ------------------------------------------------------------*/
#define VOLCANO_BOUND_LEFT      10
#define VOLCANO_BOUND_TOP       26
#define VOLCANO_BOUND_RIGHT     470
#define VOLCANO_BOUND_BOTTOM    240

#define VOLCANO_SHOOT_WAIT      25                      // 25 frames between shots
#define VOLCANO_WAIT            9                       // 9 frames between shots

#define VOLCANO_MAX_VOLCANO     16
#define VOLCANO_MAX_ALIVE       8
#define VOLCANO_MAX_SHOTS       4
#define VOLCANO_MAX_CANNONS     3

const uint8_t Volcano1Icon[16][16] = {
{2,2,2,2,1,1,1,1,1,1,1,1,2,2,2,2},
{2,2,2,2,1,1,1,1,1,1,1,1,2,2,2,2},
{2,2,2,2,2,2,2,2,1,1,1,1,2,2,2,2},
{2,2,2,2,2,2,2,2,1,1,1,1,2,2,2,2},
{1,1,1,1,1,1,1,1,1,1,1,1,2,2,1,1},
{1,1,1,1,1,1,1,1,1,1,1,1,2,2,1,1},
{1,1,1,1,1,1,1,1,1,1,1,1,2,2,1,1},
{1,1,1,1,1,1,1,1,1,1,1,1,2,2,1,1},
{1,1,2,2,1,1,1,1,1,1,1,1,1,1,1,1},
{1,1,2,2,1,1,1,1,1,1,1,1,1,1,1,1},
{1,1,2,2,1,1,1,1,1,1,1,1,1,1,1,1},
{1,1,2,2,1,1,1,1,1,1,1,1,1,1,1,1},
{2,2,2,2,1,1,1,1,2,2,2,2,2,2,2,2},
{2,2,2,2,1,1,1,1,2,2,2,2,2,2,2,2},
{2,2,2,2,1,1,1,1,1,1,1,1,2,2,2,2},
{2,2,2,2,1,1,1,1,1,1,1,1,2,2,2,2}
};

const uint8_t Volcano2Icon[16][16] = {
{2,2,2,2,2,1,2,2,2,2,1,2,2,2,2,2},
{2,2,2,2,1,1,2,2,2,2,1,1,2,2,2,2},
{2,2,2,1,1,1,2,2,2,2,2,1,1,2,2,2},
{2,2,1,1,1,1,1,2,2,2,2,2,1,1,2,2},
{2,1,1,2,2,1,1,2,2,2,2,2,1,1,1,2},
{1,1,2,2,2,1,1,1,1,1,1,1,1,1,1,1},
{2,2,2,2,2,1,1,1,1,1,1,1,1,2,2,2},
{2,2,2,2,2,1,1,1,1,1,1,2,2,2,2,2},
{2,2,2,2,2,1,1,1,1,1,1,2,2,2,2,2},
{2,2,2,1,1,1,1,1,1,1,1,2,2,2,2.2},
{1,1,1,1,1,1,1,1,1,1,1,2,2,2,1,1},
{2,1,1,2,2,2,2,2,2,1,1,2,2,1,1,2},
{2,2,1,1,2,2,2,2,2,1,1,2,1,1,2,2},
{2,2,2,1,1,2,2,2,2,2,1,1,1,2,2,2},
{2,2,2,2,1,1,2,2,2,2,1,1,2,2,2,2},
{2,2,2,2,2,1,2,2,2,2,1,2,2,2,2,2}
};

const uint8_t Volcano3Icon[16][16] = {
{2,2,2,2,1,1,1,1,1,1,1,1,2,2,2,2},
{2,2,2,2,1,1,1,1,1,1,1,1,2,2,2,2},
{2,2,2,2,1,1,1,1,2,2,2,2,2,2,2,2},
{2,2,2,2,1,1,1,1,2,2,2,2,2,2,2,2},
{1,1,2,2,1,1,1,1,1,1,1,1,1,1,1,1},
{1,1,2,2,1,1,1,1,1,1,1,1,1,1,1,1},
{1,1,2,2,1,1,1,1,1,1,1,1,1,1,1,1},
{1,1,2,2,1,1,1,1,1,1,1,1,1,1,1,1},
{1,1,1,1,1,1,1,1,1,1,1,1,2,2,1,1},
{1,1,1,1,1,1,1,1,1,1,1,1,2,2,1,1},
{1,1,1,1,1,1,1,1,1,1,1,1,2,2,1,1},
{1,1,1,1,1,1,1,1,1,1,1,1,2,2,1,1},
{2,2,2,2,2,2,2,2,1,1,1,1,2,2,2,2},
{2,2,2,2,2,2,2,2,1,1,1,1,2,2,2,2},
{2,2,2,2,1,1,1,1,1,1,1,1,2,2,2,2},
{2,2,2,2,1,1,1,1,1,1,1,1,2,2,2,2}
};

const uint8_t Volcano4Icon[16][16] = {
{2,2,2,2,2,1,2,2,2,2,1,2,2,2,2,2},
{2,2,2,2,1,1,2,2,2,2,1,1,2,2,2,2},
{2,2,2,1,1,2,2,2,2,2,1,1,1,2,2,2},
{2,2,1,1,2,2,2,2,2,1,1,1,1,1,2,2},
{2,1,1,1,2,2,2,2,2,1,1,2,2,1,1,2},
{1,1,1,1,1,1,1,1,1,1,1,2,2,2,1,1},
{2,2,2,1,1,1,1,1,1,1,1,2,2,2,2,2},
{2,2,2,2,2,1,1,1,1,1,1,2,2,2,2,2},
{2,2,2,2,2,1,1,1,1,1,1,2,2,2,2,2},
{2,2,2,2,2,1,1,1,1,1,1,1,1,2,2.2},
{1,1,2,2,2,1,1,1,1,1,1,1,1,1,1,1},
{2,1,1,2,2,1,1,2,2,2,2,2,2,1,1,2},
{2,2,1,1,2,1,1,2,2,2,2,2,1,1,2,2},
{2,2,2,1,1,1,2,2,2,2,2,1,1,2,2,2},
{2,2,2,2,1,1,2,2,2,2,1,1,2,2,2,2},
{2,2,2,2,2,1,2,2,2,2,1,2,2,2,2,2}
};

const uint8_t VolcanoCannonIcon[16][20] = {
{2,2,2,2,2,2,1,1,1,1,1,1,1,1,2,2,2,2,2,2},
{2,2,2,2,2,2,1,1,1,1,1,1,1,1,2,2,2,2,2,2},
{2,2,2,2,2,2,1,1,1,1,1,1,1,1,2,2,2,2,2,2},
{2,2,2,2,2,2,1,1,1,1,1,1,1,1,2,2,2,2,2,2},
{2,2,2,2,2,2,1,1,1,1,1,1,1,1,2,2,2,2,2,2},
{2,2,2,2,2,2,1,1,1,1,1,1,1,1,2,2,2,2,2,2},
{2,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2},
{2,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2},
{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
};

const uint8_t VolcanoShotIcon[8][3] = {
{1,1,1},
{1,1,1},
{1,1,1},
{1,1,1},
{1,1,1},
{1,1,1},
{1,1,1},
{1,1,1}
};

typedef struct
{
  SPRITE VolcanoSprite;                 // Volcano sprite
  volatile int16_t vdir;                // Volcano move
  volatile int16_t vicon;               // Volcano move
} VOLCANO;

typedef struct
{
  volatile uint8_t DemoMode;            // Demo mode flag
  volatile uint8_t GameOver;            // Game over flag
  volatile uint8_t Quit;                // Quit flag
  volatile int8_t Cannons;              // Number of spare Cannons
  volatile uint8_t Volcanos;            // Number of active volcanos
  volatile uint8_t Shots;               // Number of active shots
  volatile uint8_t ShootWait;           // Number of frames between shots
  volatile uint8_t ShotsCount;          // Number of shots fired
  volatile uint16_t Points;             // Points
  volatile uint16_t PointsCount;        // Points counter
  volatile int16_t sdir,slen;           // Cannon move
  volatile uint16_t VolcanoWait;        // Number of frames between new volcano
  RECT VolcanoBound;                    // Game bounds
  VOLCANO Volcano[VOLCANO_MAX_VOLCANO]; // Volcano sprites
  SPRITE Cannon;                        // Cannon sprite
  SPRITE Shot[VOLCANO_MAX_SHOTS];       // Shot sprites
  WINDOW* hmsgbox;                      // Handle to message box
} VOLCANO_GAME;
