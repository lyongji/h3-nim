/*
 * Copyright 2016-2021 Uber Technologies, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *         http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
/** @file h3api.h
 * @brief   Primary H3 core library entry points.
 *
 * Generated from h3api.h.in for Nim build (bypass CMake).
 * H3 version: 4.5.0
 */

#ifndef H3API_H
#define H3API_H

#ifdef H3_PREFIX
#define XTJOIN(a, b) a##b
#define TJOIN(a, b) XTJOIN(a, b)
#define H3_EXPORT(name) TJOIN(H3_PREFIX, name)
#else
#define H3_EXPORT(name) name
#endif

#if _WIN32 && BUILD_SHARED_LIBS
#if BUILDING_H3
#define DECLSPEC __declspec(dllexport)
#else
#define DECLSPEC __declspec(dllimport)
#endif
#else
#define DECLSPEC
#endif

#include <stdint.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef uint64_t H3Index;
#define H3_NULL 0
typedef uint32_t H3Error;

typedef enum {
    E_SUCCESS = 0, E_FAILED = 1, E_DOMAIN = 2, E_LATLNG_DOMAIN = 3,
    E_RES_DOMAIN = 4, E_CELL_INVALID = 5, E_DIR_EDGE_INVALID = 6,
    E_UNDIR_EDGE_INVALID = 7, E_VERTEX_INVALID = 8, E_PENTAGON = 9,
    E_DUPLICATE_INPUT = 10, E_NOT_NEIGHBORS = 11, E_RES_MISMATCH = 12,
    E_MEMORY_ALLOC = 13, E_MEMORY_BOUNDS = 14, E_OPTION_INVALID = 15,
    E_INDEX_INVALID = 16, E_BASE_CELL_DOMAIN = 17, E_DIGIT_DOMAIN = 18,
    E_DELETED_DIGIT = 19, H3_ERROR_END
} H3ErrorCodes;

DECLSPEC const char *H3_EXPORT(describeH3Error)(H3Error err);

#define H3_VERSION_MAJOR 4
#define H3_VERSION_MINOR 5
#define H3_VERSION_PATCH 0

#define MAX_CELL_BNDRY_VERTS 10

typedef struct { double lat; double lng; } LatLng;

typedef struct {
    int numVerts;
    LatLng verts[MAX_CELL_BNDRY_VERTS];
} CellBoundary;

typedef struct {
    int numVerts;
    LatLng *verts;
} GeoLoop;

typedef struct {
    GeoLoop geoloop;
    int numHoles;
    GeoLoop *holes;
} GeoPolygon;

typedef struct {
    int numPolygons;
    GeoPolygon *polygons;
} GeoMultiPolygon;

typedef enum {
    CONTAINMENT_CENTER = 0, CONTAINMENT_FULL = 1,
    CONTAINMENT_OVERLAPPING = 2, CONTAINMENT_OVERLAPPING_BBOX = 3,
    CONTAINMENT_INVALID = 4
} ContainmentMode;

typedef struct LinkedLatLng LinkedLatLng;
struct LinkedLatLng { LatLng vertex; LinkedLatLng *next; };

typedef struct LinkedGeoLoop LinkedGeoLoop;
struct LinkedGeoLoop { LinkedLatLng *first; LinkedLatLng *last; LinkedGeoLoop *next; };

typedef struct LinkedGeoPolygon LinkedGeoPolygon;
struct LinkedGeoPolygon { LinkedGeoLoop *first; LinkedGeoLoop *last; LinkedGeoPolygon *next; };

typedef struct { int i; int j; } CoordIJ;

DECLSPEC H3Error H3_EXPORT(latLngToCell)(const LatLng *g, int res, H3Index *out);
DECLSPEC H3Error H3_EXPORT(cellToLatLng)(H3Index h3, LatLng *g);
DECLSPEC H3Error H3_EXPORT(cellToBoundary)(H3Index h3, CellBoundary *gp);
DECLSPEC H3Error H3_EXPORT(maxGridDiskSize)(int k, int64_t *out);
DECLSPEC H3Error H3_EXPORT(gridDiskUnsafe)(H3Index origin, int k, H3Index *out);
DECLSPEC H3Error H3_EXPORT(gridDiskDistancesUnsafe)(H3Index origin, int k, H3Index *out, int *distances);
DECLSPEC H3Error H3_EXPORT(gridDiskDistancesSafe)(H3Index origin, int k, H3Index *out, int *distances);
DECLSPEC H3Error H3_EXPORT(gridDisksUnsafe)(H3Index *h3Set, int length, int k, H3Index *out);
DECLSPEC H3Error H3_EXPORT(gridDisk)(H3Index origin, int k, H3Index *out);
DECLSPEC H3Error H3_EXPORT(gridDiskDistances)(H3Index origin, int k, H3Index *out, int *distances);
DECLSPEC H3Error H3_EXPORT(maxGridRingSize)(int k, int64_t *out);
DECLSPEC H3Error H3_EXPORT(gridRingUnsafe)(H3Index origin, int k, H3Index *out);
DECLSPEC H3Error H3_EXPORT(gridRing)(H3Index origin, int k, H3Index *out);
DECLSPEC H3Error H3_EXPORT(maxPolygonToCellsSize)(const GeoPolygon *geoPolygon, int res, uint32_t flags, int64_t *out);
DECLSPEC H3Error H3_EXPORT(polygonToCells)(const GeoPolygon *geoPolygon, int res, uint32_t flags, H3Index *out);
DECLSPEC H3Error H3_EXPORT(maxPolygonToCellsSizeExperimental)(const GeoPolygon *polygon, int res, uint32_t flags, int64_t *out);
DECLSPEC H3Error H3_EXPORT(polygonToCellsExperimental)(const GeoPolygon *polygon, int res, uint32_t flags, int64_t size, H3Index *out);
DECLSPEC H3Error H3_EXPORT(cellsToLinkedMultiPolygon)(const H3Index *h3Set, const int numHexes, LinkedGeoPolygon *out);
DECLSPEC void H3_EXPORT(destroyLinkedMultiPolygon)(LinkedGeoPolygon *polygon);
DECLSPEC double H3_EXPORT(degsToRads)(double degrees);
DECLSPEC double H3_EXPORT(radsToDegs)(double radians);
DECLSPEC double H3_EXPORT(greatCircleDistanceRads)(const LatLng *a, const LatLng *b);
DECLSPEC double H3_EXPORT(greatCircleDistanceKm)(const LatLng *a, const LatLng *b);
DECLSPEC double H3_EXPORT(greatCircleDistanceM)(const LatLng *a, const LatLng *b);
DECLSPEC H3Error H3_EXPORT(getHexagonAreaAvgKm2)(int res, double *out);
DECLSPEC H3Error H3_EXPORT(getHexagonAreaAvgM2)(int res, double *out);
DECLSPEC H3Error H3_EXPORT(cellAreaRads2)(H3Index h, double *out);
DECLSPEC H3Error H3_EXPORT(cellAreaKm2)(H3Index h, double *out);
DECLSPEC H3Error H3_EXPORT(cellAreaM2)(H3Index h, double *out);
DECLSPEC H3Error H3_EXPORT(getHexagonEdgeLengthAvgKm)(int res, double *out);
DECLSPEC H3Error H3_EXPORT(getHexagonEdgeLengthAvgM)(int res, double *out);
DECLSPEC H3Error H3_EXPORT(edgeLengthRads)(H3Index edge, double *length);
DECLSPEC H3Error H3_EXPORT(edgeLengthKm)(H3Index edge, double *length);
DECLSPEC H3Error H3_EXPORT(edgeLengthM)(H3Index edge, double *length);
DECLSPEC H3Error H3_EXPORT(getNumCells)(int res, int64_t *out);
DECLSPEC int H3_EXPORT(res0CellCount)(void);
DECLSPEC H3Error H3_EXPORT(getRes0Cells)(H3Index *out);
DECLSPEC int H3_EXPORT(pentagonCount)(void);
DECLSPEC H3Error H3_EXPORT(getPentagons)(int res, H3Index *out);
DECLSPEC int H3_EXPORT(getResolution)(H3Index h);
DECLSPEC int H3_EXPORT(getBaseCellNumber)(H3Index h);
DECLSPEC H3Error H3_EXPORT(getIndexDigit)(H3Index h, int res, int *out);
DECLSPEC H3Error H3_EXPORT(constructCell)(int res, int baseCellNumber, const int *digits, H3Index *out);
DECLSPEC H3Error H3_EXPORT(stringToH3)(const char *str, H3Index *out);
DECLSPEC H3Error H3_EXPORT(h3ToString)(H3Index h, char *str, size_t sz);
DECLSPEC int H3_EXPORT(isValidCell)(H3Index h);
DECLSPEC int H3_EXPORT(isValidIndex)(H3Index h);
DECLSPEC H3Error H3_EXPORT(cellToParent)(H3Index h, int parentRes, H3Index *parent);
DECLSPEC H3Error H3_EXPORT(cellToChildrenSize)(H3Index h, int childRes, int64_t *out);
DECLSPEC H3Error H3_EXPORT(cellToChildren)(H3Index h, int childRes, H3Index *children);
DECLSPEC H3Error H3_EXPORT(cellToCenterChild)(H3Index h, int childRes, H3Index *child);
DECLSPEC H3Error H3_EXPORT(cellToChildPos)(H3Index child, int parentRes, int64_t *out);
DECLSPEC H3Error H3_EXPORT(childPosToCell)(int64_t childPos, H3Index parent, int childRes, H3Index *child);
DECLSPEC H3Error H3_EXPORT(compactCells)(const H3Index *h3Set, H3Index *compactedSet, const int64_t numHexes);
DECLSPEC H3Error H3_EXPORT(uncompactCellsSize)(const H3Index *compactedSet, const int64_t numCompacted, const int res, int64_t *out);
DECLSPEC H3Error H3_EXPORT(uncompactCells)(const H3Index *compactedSet, const int64_t numCompacted, H3Index *outSet, const int64_t numOut, const int res);
DECLSPEC int H3_EXPORT(isResClassIII)(H3Index h);
DECLSPEC int H3_EXPORT(isPentagon)(H3Index h);
DECLSPEC H3Error H3_EXPORT(maxFaceCount)(H3Index h3, int *out);
DECLSPEC H3Error H3_EXPORT(getIcosahedronFaces)(H3Index h3, int *out);
DECLSPEC H3Error H3_EXPORT(areNeighborCells)(H3Index origin, H3Index destination, int *out);
DECLSPEC H3Error H3_EXPORT(cellsToDirectedEdge)(H3Index origin, H3Index destination, H3Index *out);
DECLSPEC int H3_EXPORT(isValidDirectedEdge)(H3Index edge);
DECLSPEC H3Error H3_EXPORT(getDirectedEdgeOrigin)(H3Index edge, H3Index *out);
DECLSPEC H3Error H3_EXPORT(getDirectedEdgeDestination)(H3Index edge, H3Index *out);
DECLSPEC H3Error H3_EXPORT(directedEdgeToCells)(H3Index edge, H3Index *originDestination);
DECLSPEC H3Error H3_EXPORT(originToDirectedEdges)(H3Index origin, H3Index *edges);
DECLSPEC H3Error H3_EXPORT(directedEdgeToBoundary)(H3Index edge, CellBoundary *gb);
DECLSPEC H3Error H3_EXPORT(reverseDirectedEdge)(H3Index edge, H3Index *out);
DECLSPEC H3Error H3_EXPORT(cellToVertex)(H3Index origin, int vertexNum, H3Index *out);
DECLSPEC H3Error H3_EXPORT(cellToVertexes)(H3Index origin, H3Index *vertexes);
DECLSPEC H3Error H3_EXPORT(vertexToLatLng)(H3Index vertex, LatLng *point);
DECLSPEC int H3_EXPORT(isValidVertex)(H3Index vertex);
DECLSPEC H3Error H3_EXPORT(gridDistance)(H3Index origin, H3Index h3, int64_t *distance);
DECLSPEC H3Error H3_EXPORT(gridPathCellsSize)(H3Index start, H3Index end, int64_t *size);
DECLSPEC H3Error H3_EXPORT(gridPathCells)(H3Index start, H3Index end, H3Index *out);
DECLSPEC H3Error H3_EXPORT(cellToLocalIj)(H3Index origin, H3Index h3, uint32_t mode, CoordIJ *out);
DECLSPEC H3Error H3_EXPORT(localIjToCell)(H3Index origin, const CoordIJ *ij, uint32_t mode, H3Index *out);

#ifdef __cplusplus
}
#endif

#endif
