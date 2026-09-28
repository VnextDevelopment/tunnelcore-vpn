package org.amnezia.vpn.util.net

import java.util.TreeSet

class IpRangeSet {

    private val ranges = TreeSet<IpRange>()

    fun add(ipRange: IpRange) {
        var rangeToAdd = ipRange

        // GeoIP split-tunnel lists contain thousands of ranges. Looking up only
        // adjacent ranges avoids rescanning the whole set for every insertion.
        ranges.floor(rangeToAdd)?.let { lowerRange ->
            (lowerRange + rangeToAdd)?.let { mergedRange ->
                if (mergedRange == lowerRange) return
                ranges.remove(lowerRange)
                rangeToAdd = mergedRange
            }
        }

        while (true) {
            val upperRange = ranges.ceiling(rangeToAdd) ?: break
            val mergedRange = upperRange + rangeToAdd ?: break
            ranges.remove(upperRange)
            rangeToAdd = mergedRange
        }

        ranges += rangeToAdd
    }

    fun remove(ipRange: IpRange) {
        // Start at the range containing the removal boundary (or the next one)
        // and visit only ranges that can overlap it.
        var currentRange = ranges.floor(ipRange) ?: ranges.ceiling(ipRange)
        while (currentRange != null && currentRange.start <= ipRange.end) {
            val nextRange = ranges.higher(currentRange)
            (currentRange - ipRange)?.let { remainingRanges ->
                ranges.remove(currentRange)
                ranges += remainingRanges
            }
            currentRange = nextRange
        }
    }

    fun subnets(): List<InetNetwork> = ranges.map(IpRange::subnets).flatten()

    override fun toString(): String = ranges.toString()
}
