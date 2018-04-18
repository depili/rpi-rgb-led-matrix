// -*- mode: c++; c-basic-offset: 2; indent-tabs-mode: nil; -*-
//
// This code is public domain
// (but note, once linked against the led-matrix library, this is
// covered by the GPL v2)

#include "led-matrix.h"
#include "threaded-canvas-manipulator.h"
#include "transformer.h"
#include "graphics.h"

#include <assert.h>
#include <getopt.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <algorithm>

#include <arpa/inet.h>
#include <signal.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/types.h>

using std::min;
using std::max;

using namespace rgb_matrix;

volatile bool interrupt_received = false;
static void InterruptHandler(int signo) {
  interrupt_received = true;
}

static int usage(const char *progname) {
  fprintf(stderr, "usage: %s <options> -D <demo-nr> [optional parameter]\n",
          progname);
  fprintf(stderr, "Options:\n"
          "\t-r <rows>     : Panel rows. '16' for 16x32 (1:8 multiplexing),\n"
	  "\t                '32' for 32x32 (1:16), '8' for 1:4 multiplexing; 64 for 1:32 multiplexing. "
          "Default: 32\n"
          "\t-P <parallel> : For Plus-models or RPi2: parallel chains. 1..3. "
          "Default: 1\n"
          "\t-c <chained>  : Daisy-chained boards. Default: 1.\n"
          "\t-L            : 'Large' display, composed out of 4 times 32x32\n"
          "\t-p <pwm-bits> : Bits used for PWM. Something between 1..11\n"
          "\t-l            : Don't do luminance correction (CIE1931)\n"
          "\t-d            : run as daemon. Use this when starting in\n"
          "\t                /etc/init.d, but also when running without\n"
          "\t                terminal (e.g. cron).\n"
          "\t-b <brightnes>: Sets brightness percent. Default: 100.\n"
          "\t-R <rotation> : Sets the rotation of matrix. Allowed: 0, 90, 180, 270. Default: 0.\n");
  return 1;
}

int main(int argc, char *argv[]) {
  GPIO io;
  int rows = 32;
  int chain = 1;
  int parallel = 1;
  int scroll_ms = 30;
  int pwm_bits = -1;
  int brightness = 100;
  int rotation = 0;
  bool large_display = false;
  bool do_luminance_correct = true;

  int opt;
  while ((opt = getopt(argc, argv, "dlD:t:r:P:c:p:b:m:LR:")) != -1) {
    switch (opt) {
    case 'r':
      rows = atoi(optarg);
      break;

    case 'P':
      parallel = atoi(optarg);
      break;

    case 'c':
      chain = atoi(optarg);
      break;

    case 'm':
      scroll_ms = atoi(optarg);
      break;

    case 'p':
      pwm_bits = atoi(optarg);
      break;

    case 'b':
      brightness = atoi(optarg);
      break;

    case 'l':
      do_luminance_correct = !do_luminance_correct;
      break;

    case 'L':
      // The 'large' display assumes a chain of four displays with 32x32
      chain = 4;
      rows = 32;
      large_display = true;
      break;

    case 'R':
      rotation = atoi(optarg);
      break;

    default: /* '?' */
      return usage(argv[0]);
    }
  }

  if (getuid() != 0) {
    fprintf(stderr, "Must run as root to be able to access /dev/mem\n"
            "Prepend 'sudo' to the command:\n\tsudo %s ...\n", argv[0]);
    return 1;
  }

  if (rows != 8 && rows != 16 && rows != 32 && rows != 64) {
    fprintf(stderr, "Rows can one of 8, 16, 32 or 64 "
            "for 1:4, 1:8, 1:16 and 1:32 multiplexing respectively.\n");
    return 1;
  }

  if (chain < 1) {
    fprintf(stderr, "Chain outside usable range\n");
    return 1;
  }
  if (chain > 8) {
    fprintf(stderr, "That is a long chain. Expect some flicker.\n");
  }
  if (parallel < 1 || parallel > 3) {
    fprintf(stderr, "Parallel outside usable range.\n");
    return 1;
  }

  if (brightness < 1 || brightness > 100) {
    fprintf(stderr, "Brightness is outside usable range.\n");
    return 1;
  }

  if (rotation % 90 != 0) {
    fprintf(stderr, "Rotation %d not allowed! Only 0, 90, 180 and 270 are possible.\n", rotation);
    return 1;
  }

  // Initialize GPIO pins. This might fail when we don't have permissions.
  if (!io.Init())
    return 1;

  // Start daemon before we start any threads.
  if (as_daemon) {
    if (fork() != 0)
      return 0;
    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);
  }

  // The matrix, our 'frame buffer' and display updater.
  RGBMatrix *matrix = new RGBMatrix(&io, rows, chain, parallel);
  matrix->set_luminance_correct(do_luminance_correct);
  matrix->SetBrightness(brightness);
  if (pwm_bits >= 0 && !matrix->SetPWMBits(pwm_bits)) {
    fprintf(stderr, "Invalid range of pwm-bits\n");
    return 1;
  }

  LinkedTransformer *transformer = new LinkedTransformer();
  matrix->SetTransformer(transformer);

  if (large_display) {
    // Mapping the coordinates of a 32x128 display mapped to a square of 64x64
    transformer->AddTransformer(new LargeSquare64x64Transformer());
  }

  if (rotation > 0) {
    transformer->AddTransformer(new RotateTransformer(rotation));
  }

  Canvas *canvas = matrix->CreateFrameCanvas();






  delete canvas;

  transformer->DeleteTransformers();
  delete transformer;

  return 0;
}
