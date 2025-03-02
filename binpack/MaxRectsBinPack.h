/** @file MaxRectsBinPack.h
	@author Jukka Jyl�nki

	@brief Implements different bin packer algorithms that use the MAXRECTS data structure.

	This work is released to Public Domain, do whatever you want with it.
*/
#ifndef MAXRECTSBINPACK_H
#define MAXRECTSBINPACK_H

#include "AbstractBinPack.h"
#include <vector>
#include "Rect.h"
#include <swift/bridging>

using InputVector = std::vector<BaseRectSize>;
using OutputVector = std::vector<BaseRect>;

/** MaxRectsBinPack implements the MAXRECTS data structure and different bin packing algorithms that
	use this structure. */
class MaxRectsBinPack : public AbstractBinPack
    {
    public:
        /// Instantiates a bin of size (0,0). Call Init to create a new bin.
        MaxRectsBinPack();

        /// Instantiates a bin of the given size.
        MaxRectsBinPack(int width, int height);

        /// (Re)initializes the packer to an empty bin of width x height units. Call whenever
        /// you need to restart with a new bin.
        void Init(int width, int height);

        /// Specifies the different heuristic rules that can be used when deciding where to place a new rectangle.
        enum FreeRectChoiceHeuristic
            {
            RectBestShortSideFit, ///< -BSSF: Positions the rectangle against the short side of a free rectangle into which it fits the best.
            RectBestLongSideFit, ///< -BLSF: Positions the rectangle against the long side of a free rectangle into which it fits the best.
            RectBestAreaFit, ///< -BAF: Positions the rectangle into the smallest free rect into which it fits.
            RectBottomLeftRule, ///< -BL: Does the Tetris placement.
            RectContactPointRule ///< -CP: Choosest the placement where the rectangle touches other rects as much as possible.
            };

        /// Inserts the given list of rectangles in an offline/batch mode, possibly rotated.
        /// @param rects The list of rectangles to insert. This vector will be destroyed in the process.
        /// @param dst [out] This list will contain the packed rectangles. The indices will not correspond to that of rects.
        /// @param method The rectangle placement rule to use when packing.
        void Insert(std::vector<BaseRectSize> &rects, std::vector<BaseRect> &dst, FreeRectChoiceHeuristic method);

        /// Inserts a single rectangle into the bin, possibly rotated.
        BaseRect Insert(int width, int height, int method);

        /// Computes the ratio of used surface area to the total bin area.
        float Occupancy() const;
    
        std::vector<BaseRect> getUsedRectangles() const SWIFT_COMPUTED_PROPERTY { return usedRectangles; }

    private:
        int binWidth;
        int binHeight;

        std::vector<BaseRect> usedRectangles;
        std::vector<BaseRect> freeRectangles;

        /// Computes the placement score for placing the given rectangle with the given method.
        /// @param score1 [out] The primary placement score will be outputted here.
        /// @param score2 [out] The secondary placement score will be outputted here. This isu sed to break ties.
        /// @return This struct identifies where the rectangle would be placed if it were placed.
        BaseRect ScoreRect(int width, int height, FreeRectChoiceHeuristic method, int &score1, int &score2) const;

        /// Places the given rectangle into the bin.
        void PlaceRect(const BaseRect &node);

        /// Computes the placement score for the -CP variant.
        int ContactPointScoreNode(int x, int y, int width, int height) const;

        BaseRect FindPositionForNewNodeBottomLeft(int width, int height, int &bestY, int &bestX) const;
        BaseRect FindPositionForNewNodeBestShortSideFit(int width, int height, int &bestShortSideFit, int &bestLongSideFit) const;
        BaseRect FindPositionForNewNodeBestLongSideFit(int width, int height, int &bestShortSideFit, int &bestLongSideFit) const;
        BaseRect FindPositionForNewNodeBestAreaFit(int width, int height, int &bestAreaFit, int &bestShortSideFit) const;
        BaseRect FindPositionForNewNodeContactPoint(int width, int height, int &contactScore) const;

        /// @return True if the free node was split.
        bool SplitFreeNode(BaseRect freeNode, const BaseRect &usedNode);

        /// Goes through the free rectangle list and removes any redundant entries.
        void PruneFreeList();
    };

#endif // #define MAXRECTSBINPACK_H
