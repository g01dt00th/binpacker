#include "generate.hpp"
#include "bstrlib.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <float.h>

#define NANOSVG_IMPLEMENTATION
#define NANOSVGRAST_IMPLEMENTATION

//#include "stb_image_write.h"
#include "nanosvg.h"
#include "nanosvgrast.h"
#include "bstrlib.h"
#include "bstradd.h"

#define max(a,b) \
   ({ __typeof__ (a) _a = (a); \
       __typeof__ (b) _b = (b); \
     _a > _b ? _a : _b; })

static const int tileSize = 96;

static void rasterizeToImage(bstring svgString, SvgCodeImage* image, bool scaleToParent) {
    NSVGrasterizer* rast = NULL;
    NSVGimage *svg = nsvgParse((char*) svgString->data, "px", (float) tileSize);

    if (svg == NULL) {
        goto error;
    }

    float scale = 0.0;
    if (scaleToParent) {
        scale = (float) image->width / (float) svg->width;
    } else {
        scale = (float) image->width / (float) image->totalWidth;
    }
    
    int w = image->width;
    int h = image->height;

    rast = nsvgCreateRasterizer();
    if (rast == NULL) {
        goto error;
    }

    unsigned char* buffer = malloc(w * h * 4);
    nsvgRasterize(rast, svg, 0, 0, scale, buffer, w, h, w * 4);

    image->pixels = (char *) buffer;

error:
    nsvgDeleteRasterizer(rast);
    nsvgDelete(svg);
}


SvgSize getSVGImageSize(const char* svgImage) {
    bstring result = bfromcstr("");

    struct bstrList* parts = bstrListCreateMin(1);

    bstring points = bjoinInv(parts, bfromcstr("\n"));
    bformata(result, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    bformata(result, "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n");
    bformata(result, "%s", svgImage);

    bdestroy(points);
    bstrListDestroy(parts);
    
    NSVGimage *svg = nsvgParse((char*) result->data, "px", (float) tileSize);
    bdestroy(result);
    
    SvgSize size;
    size.width = svg -> width;
    size.height = svg -> height;
    
    return size;
}

void generateSVGImage(const char* svgImage, SvgCodeImage* image, int width, int height) {
    bstring result = bfromcstr("");

    image->width = width;
    image->height = height;
    image->totalWidth = width;
    image->totalHeight = height;

    struct bstrList* parts = bstrListCreateMin(1);

    bstring points = bjoinInv(parts, bfromcstr("\n"));

    bformata(result, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    bformata(result, "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n");
    bformata(result, "%s", svgImage);

    bdestroy(points);
    bstrListDestroy(parts);

    rasterizeToImage(result, image, true);
    bdestroy(result);
}

