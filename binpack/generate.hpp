//
//  generate.h
//  Maps
//
//  Created by d.roenko on 04.04.2023.
//

#ifndef generate_h
#define generate_h
#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    float x;
    float y;
    float width;
    float height;
} SvgRect;

typedef struct {
    int width;
    int height;
    char* pixels;
    SvgRect logoFrame;
    
    int totalWidth;
    int totalHeight;
} SvgCodeImage;

typedef struct {
    int width;
    int height;
} SvgSize;

SvgSize getSVGImageSize(const char* svgImage);
    // don't forget to free(SvgCodeImage.pixels)
void generateSVGImage(const char* svgImage, SvgCodeImage* image, int width, int height);

#ifdef __cplusplus
}
#endif
#endif /* generate_h */
