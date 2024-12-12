#ifndef ABSTRACTBINPACK_H
#define ABSTRACTBINPACK_H

#include "Rect.h"

class AbstractBinPack
    {
    public:
        /// (Re)initializes the packer to an empty bin of width x height units. Call whenever
        /// you need to restart with a new bin.
        virtual void Init (int width, int height) = 0;

        /// Inserts a single rectangle into the bin, possibly rotated.
        virtual BaseRect Insert(int width, int height, int method) = 0;

        /// Computes the ratio of used surface area to the total bin area.
        virtual float Occupancy() const = 0;
    };

#endif //  #define ABSTRACTBINPACK_H
