# cython: language_level=3

#includes
# needed for collections.Iterable
from networkit.exceptions import ReducedFunctionalityWarning
import collections
import math
import os
import tempfile
import warnings

try:
	import pandas
except:
	warnings.warn("WARNING: module 'pandas' not found, some functionality will be restricted", ReducedFunctionalityWarning)

# C++ operators
from cython.operator import dereference, preincrement

# type imports
from libc.stdint cimport uint64_t
from libc.stdint cimport int64_t
from libc.stdint cimport uint8_t

# the C++ standard library
from libcpp cimport bool as bool_t
from libcpp.vector cimport vector
from libcpp.utility cimport pair
from libcpp.map cimport map
from libcpp.set cimport set
from libcpp.stack cimport stack
from libcpp.string cimport string
from libcpp.unordered_set cimport unordered_set
from libcpp.unordered_map cimport unordered_map
from libcpp.algorithm cimport sort as stdsort

# NetworKit typedefs
ctypedef uint64_t count
ctypedef uint64_t index
ctypedef uint64_t edgeid
ctypedef index node
ctypedef index cluster
ctypedef double edgeweight
ctypedef double coordinate

from .base cimport _Algorithm
from .base cimport Algorithm
from .graph cimport _Graph, Graph
from .structures cimport _Cover, Cover, _Partition, Partition
from .matching cimport _Matching, Matching
from networkit.graphtools import GraphTools
from .dynamics cimport _GraphEvent, GraphEvent

cdef extern from "<networkit/Globals.hpp>" namespace "NetworKit":

	index _none "NetworKit::none"

none = _none

def stdstring(pystring):
	""" convert a Python string to a bytes object which is automatically coerced to std::string"""
	pybytes = pystring.encode("utf-8")
	return pybytes

def pystring(stdstring):
	""" convert a std::string (= python byte string) to a normal Python string"""
	return stdstring.decode("utf-8")

cdef extern from "cython_helper.h":
	void throw_runtime_error(string message)

cdef extern from "<algorithm>" namespace "std":
	void swap[T](T &a,  T &b)
	_Graph move( _Graph t ) nogil # specialized declaration as general declaration disables template argument deduction and doesn't work
	_Partition move( _Partition t) nogil
	pair[_Graph, vector[node]] move(pair[_Graph, vector[node]]) nogil
	vector[pair[pair[node, node], double]] move(vector[pair[pair[node, node], double]]) nogil
	vector[double] move(vector[double])
	vector[bool_t] move(vector[bool_t])
	vector[pair[node, node]] move(vector[pair[node, node]]) nogil

cdef extern from "<networkit/auxiliary/Parallel.hpp>" namespace "Aux::Parallel":

	void sort[Iter](Iter begin, Iter end) nogil
	void sort[Iter, Comp](Iter begin, Iter end, Comp compare) nogil

# Function definitions

cdef extern from "<networkit/auxiliary/Log.hpp>" namespace "Aux":

	#void _configureLogging "Aux::configureLogging" (string loglevel)
	string _getLogLevel "Aux::Log::getLogLevel" () except +
	void _setLogLevel "Aux::Log::setLogLevel" (string loglevel) except +
	void _setPrintLocation "Aux::Log::Settings::setPrintLocation" (bool_t) except +

def getLogLevel():
	""" Get the current log level"""
	return pystring(_getLogLevel())

def setLogLevel(loglevel):
	""" Set the current loglevel"""
	_setLogLevel(stdstring(loglevel))

def setPrintLocation(flag):
	""" Switch locations in log statements on or off"""
	_setPrintLocation(flag)

cdef extern from "<networkit/auxiliary/Parallelism.hpp>" namespace "Aux":

	void _setNumberOfThreads "Aux::setNumberOfThreads" (int)
	int _getCurrentNumberOfThreads "Aux::getCurrentNumberOfThreads" ()
	int _getMaxNumberOfThreads "Aux::getMaxNumberOfThreads" ()
	void _enableNestedParallelism "Aux::enableNestedParallelism" ()

def setNumberOfThreads(nThreads):
	""" Set the number of OpenMP threads """
	_setNumberOfThreads(nThreads)

def getCurrentNumberOfThreads():
	""" Get the number of currently running threads"""
	return _getCurrentNumberOfThreads()

def getMaxNumberOfThreads():
	""" Get the maximum number of available threads"""
	return _getMaxNumberOfThreads()

def enableNestedParallelism():
	""" Enable nested parallelism for OpenMP"""
	from warnings import warn
	warn("Nested parallelism has been deprecated.")

cdef extern from "<networkit/auxiliary/Random.hpp>" namespace "Aux::Random":

	void _setSeed "Aux::Random::setSeed" (uint64_t, bool_t)

def setSeed(uint64_t seed, bool_t useThreadId):
	""" Set the random seed that is used in NetworKit.

	Note that there is a separate random number generator per thread.

	Parameters
	----------
	seed : uint64_t
		The seed
	useThreadId : bool
		If the thread id shall be added to the seed
	"""
	_setSeed(seed, useThreadId)

# Class definitions

## Module: engineering

# TODO: timer

cdef extern from "<networkit/viz/Point.hpp>" namespace "NetworKit" nogil:

	cdef cppclass Point[T]:
		Point()
		Point(T x, T y)
		T& operator[](const index i) except +
		T& at(const index i) except +

	cdef cppclass _Point2D "NetworKit::Point2D":
		_Point2D()
		pair[coordinate, coordinate] asPair()

cdef object toPoint2DVector(const vector[_Point2D]& v):
	return [v[i].asPair() for i in range(v.size())]

cdef object toNodePoint2DVector(const vector[pair[node, _Point2D]]& v):
	return [(v[i].first, v[i].second.asPair()) for i in range(v.size())]

cdef extern from "<networkit/independentset/Luby.hpp>":

	cdef cppclass _Luby "NetworKit::Luby":
		_Luby() except +
		vector[bool_t] run(_Graph G) except +
		string toString()


# FIXME: check correctness
cdef class Luby:
	""" Luby's parallel maximal independent set algorithm"""
	cdef _Luby _this

	def run(self, Graph G not None):
		""" Returns a bool vector of length n where vec[v] is True iff v is in the independent sets.
		Parameters
		----------
		G : networkit.Graph
			The graph.
		Returns
		-------
		vector
			A bool vector of length n.
		"""
		return self._this.run(G._this)
		# TODO: return self

	def toString(self):
		""" Get string representation of the algorithm.
		Returns
		-------
		string
			The string representation of the algorithm.
		"""
		return self._this.toString().decode("utf-8")

# Module: generators


# cdef extern from "<networkit/generators/MultiscaleGenerator.hpp>":

# 	cdef cppclass _MultiscaleGenerator "NetworKit::MultiscaleGenerator":
# 		_MultiscaleGenerator(_Graph O) except +
# 		_Graph generate() except +
#
#
# cdef class MultiscaleGenerator:
# 	"""
# 	TODO:
# 	"""
# 	cdef _MultiscaleGenerator *_this
# 	cdef Graph O	# store reference to input graph to not let it be garbage-collection
#
# 	def __cinit__(self, Graph O):
# 		self._this = new _MultiscaleGenerator(O._this)
# 		self.O = O
#
# 	def generate(self):
# 		return Graph(0).setThis(self._this.generate())
#
# 	@classmethod
# 	def fit(cls, Graph G):
# 		return cls(G)





# Module: flows

cdef extern from "<networkit/flow/EdmondsKarp.hpp>":

	cdef cppclass _EdmondsKarp "NetworKit::EdmondsKarp":
		_EdmondsKarp(const _Graph &graph, node source, node sink) except +
		void run() nogil except +
		edgeweight getMaxFlow() const
		vector[node] getSourceSet() except +
		edgeweight getFlow(node u, node v) except +
		edgeweight getFlow(edgeid eid) const
		vector[edgeweight] getFlowVector() except +

cdef class EdmondsKarp:
	"""
	The EdmondsKarp class implements the maximum flow algorithm by Edmonds and Karp.

	Parameters
	----------
	graph : networkit.Graph
		The graph
	source : node
		The source node for the flow calculation
	sink : node
		The sink node for the flow calculation
	"""
	cdef _EdmondsKarp* _this
	cdef Graph _graph

	def __cinit__(self, Graph graph not None, node source, node sink):
		self._graph = graph # store reference of graph for memory management, so the graph is not deallocated before this object
		self._this = new _EdmondsKarp(graph._this, source, sink)

	def __dealloc__(self):
		del self._this

	def run(self):
		"""
		Computes the maximum flow, executes the EdmondsKarp algorithm
		"""
		with nogil:
			self._this.run()
		return self

	def getMaxFlow(self):
		"""
		Returns the value of the maximum flow from source to sink.

		Returns
		-------
		edgeweight
			The maximum flow value
		"""
		return self._this.getMaxFlow()

	def getSourceSet(self):
		"""
		Returns the set of the nodes on the source side of the flow/minimum cut.

		Returns
		-------
		list
			The set of nodes that form the (smallest) source side of the flow/minimum cut.
		"""
		return self._this.getSourceSet()

	def getFlow(self, node u, node v = none):
		"""
		Get the flow value between two nodes u and v or an edge identified by the edge id u.
		Warning: The variant with two edge ids is linear in the degree of u.

		Parameters
		----------
		u : node or edgeid
			The first node incident to the edge or the edge id
		v : node
			The second node incident to the edge (optional if edge id is specified)

		Returns
		-------
		edgeweight
			The flow on the specified edge
		"""
		if v == none: # Assume that node and edge ids are the same type
			return self._this.getFlow(u)
		else:
			return self._this.getFlow(u, v)

	def getFlowVector(self):
		"""
		Return a copy of the flow values of all edges.

		Returns
		-------
		list
			The flow values of all edges indexed by edge id
		"""
		return self._this.getFlowVector()

# Module: properties

cdef extern from "<networkit/global/ClusteringCoefficient.hpp>" namespace "NetworKit::ClusteringCoefficient":

		double avgLocal(_Graph G, bool_t turbo) nogil except +
		double sequentialAvgLocal(_Graph G) nogil except +
		double approxAvgLocal(_Graph G, count trials) nogil except +
		double exactGlobal(_Graph G) nogil except +
		double approxGlobal(_Graph G, count trials) nogil except +

cdef class ClusteringCoefficient:
	@staticmethod
	def avgLocal(Graph G, bool_t turbo = False):
		"""
		DEPRECATED: Use centrality.LocalClusteringCoefficient and take average.

		This calculates the average local clustering coefficient of graph `G`. The graph may not contain self-loops.

		Parameters
		----------
		G : networkit.Graph
			The graph.

		Notes
		-----

		.. math:: c(G) := \\frac{1}{n} \sum_{u \in V} c(u)

		where

		.. math:: c(u) := \\frac{2 \cdot |E(N(u))| }{\deg(u) \cdot ( \deg(u) - 1)}

		"""
		cdef double ret
		with nogil:
			ret = avgLocal(G._this, turbo)
		return ret

	@staticmethod
	def sequentialAvgLocal(Graph G):
		""" This calculates the average local clustering coefficient of graph `G` using inherently sequential triangle counting.
		Parameters
		----------
		G : networkit.Graph
			The graph.

		Notes
		-----

		.. math:: c(G) := \\frac{1}{n} \sum_{u \in V} c(u)

		where

		.. math:: c(u) := \\frac{2 \cdot |E(N(u))| }{\deg(u) \cdot ( \deg(u) - 1)}

		"""
		cdef double ret
		with nogil:
			ret = sequentialAvgLocal(G._this)
		return ret

	@staticmethod
	def approxAvgLocal(Graph G, count trials):
		cdef double ret
		with nogil:
			ret = approxAvgLocal(G._this, trials)
		return ret

	@staticmethod
	def exactGlobal(Graph G):
		""" This calculates the global clustering coefficient. """
		cdef double ret
		with nogil:
			ret = exactGlobal(G._this)
		return ret

	@staticmethod
	def approxGlobal(Graph G, count trials):
		cdef double ret
		with nogil:
			ret = approxGlobal(G._this, trials)
		return ret

cdef extern from "<networkit/correlation/Assortativity.hpp>":

	cdef cppclass _Assortativity "NetworKit::Assortativity"(_Algorithm):
		_Assortativity(_Graph, vector[double]) except +
		_Assortativity(_Graph, _Partition) except +
		double getCoefficient() except +

cdef class Assortativity(Algorithm):
	""" """
	cdef Graph G
	cdef vector[double] attribute
	cdef Partition partition

	def __cinit__(self, Graph G, data):
		if isinstance(data, Partition):
			self._this = new _Assortativity(G._this, (<Partition>data)._this)
			self.partition = <Partition>data
		else:
			self.attribute = <vector[double]?>data
			self._this = new _Assortativity(G._this, self.attribute)
		self.G = G

	def getCoefficient(self):
		return (<_Assortativity*>(self._this)).getCoefficient()

cdef extern from "<networkit/dynamics/GraphDifference.hpp>":

	cdef cppclass _GraphDifference "NetworKit::GraphDifference"(_Algorithm):
		_GraphDifference(const _Graph &G1, const _Graph &G2) except +
		vector[_GraphEvent] getEdits() except +
		count getNumberOfEdits() except +
		count getNumberOfNodeAdditions() except +
		count getNumberOfNodeRemovals() except +
		count getNumberOfNodeRestorations() except +
		count getNumberOfEdgeAdditions() except +
		count getNumberOfEdgeRemovals() except +
		count getNumberOfEdgeWeightUpdates() except +

cdef class GraphDifference(Algorithm):
	"""
	Calculate the edge difference between two graphs.

	This calculates which graph edge additions or edge removals are
	necessary to transform one given graph into another given graph.

	Both graphs need to have the same node set, directed graphs are not
	supported currently.

	Note that edge weight differences are not detected but edge
	addition events set the correct edge weight.

	Parameters
	----------
	G1 : networkit.Graph
		The first graph to compare
	G2 : networkit.Graph
		The second graph to compare
	"""
	cdef Graph _G1, _G2

	def __cinit__(self, Graph G1, Graph G2):
		self._this = new _GraphDifference(G1._this, G2._this)
		self._G1 = G1
		self._G2 = G2

	def getEdits(self):
		""" Get the required edits.

		Returns
		-------
		list
			A list of graph events
		"""
		cdef _GraphEvent ev
		return [GraphEvent(ev.type, ev.u, ev.v, ev.w) for ev in (<_GraphDifference*>(self._this)).getEdits()]

	def getNumberOfEdits(self):
		""" Get the required number of edits.

		Returns
		-------
		int
			The number of edits.
		"""
		return (<_GraphDifference*>(self._this)).getNumberOfEdits()

	def getNumberOfNodeAdditions(self):
		""" Get the required number of node additions.

		Returns
		-------
		int
			The number of node additions.
		"""
		return (<_GraphDifference*>(self._this)).getNumberOfNodeAdditions()

	def getNumberOfNodeRemovals(self):
		""" Get the required number of node removals.

		Returns
		-------
		int
			The number of node removals.
		"""
		return (<_GraphDifference*>(self._this)).getNumberOfNodeRemovals()

	def getNumberOfNodeRestorations(self):
		""" Get the required number of node restorations.

		Returns
		-------
		int
			The number of node restorations.
		"""
		return (<_GraphDifference*>(self._this)).getNumberOfNodeRestorations()

	def getNumberOfEdgeAdditions(self):
		""" Get the required number of edge additions.

		Returns
		-------
		int
			The number of edge additions.
		"""
		return (<_GraphDifference*>(self._this)).getNumberOfEdgeAdditions()

	def getNumberOfEdgeRemovals(self):
		""" Get the required number of edge removals.

		Returns
		-------
		int
			The number of edge removals.
		"""
		return (<_GraphDifference*>(self._this)).getNumberOfEdgeRemovals()

	def getNumberOfEdgeWeightUpdates(self):
		""" Get the required number of edge weight updates.

		Returns
		-------
		int
			The number of edge weight updates.
		"""
		return (<_GraphDifference*>(self._this)).getNumberOfEdgeWeightUpdates()



# Module: dynamic

# cdef extern from "<networkit/dcd2/DynamicCommunityDetection.hpp>":

# 	cdef cppclass _DynamicCommunityDetection "NetworKit::DynamicCommunityDetection":
# 		_DynamicCommunityDetection(string inputPath, string algoName, string updateStrategy, count interval, count restart, vector[string] recordSettings) except +
# 		void run() except +
# 		vector[double] getTimeline(string key) except +
# 		vector[pair[count, count]] getGraphSizeTimeline() except +
# 		vector[pair[_Graph, _Partition]] getResultTimeline() except +

# cdef class DynamicCommunityDetection:
# 	cdef _DynamicCommunityDetection* _this

# 	def __cinit__(self, inputPath, algoName, updateStrategy, interval, restart, recordSettings):
# 		self._this = new _DynamicCommunityDetection(stdstring(inputPath), stdstring(algoName), stdstring(updateStrategy), interval, restart, [stdstring(key) for key in recordSettings])

# 	def run(self):
# 		self._this.run()

# 	def getTimeline(self, key):
# 		return self._this.getTimeline(stdstring(key))

# 	def getGraphSizeTimeline(self):
# 		return self._this.getGraphSizeTimeline()

# 	def getResultTimeline(self):
# 		timeline = []
# 		for pair in self._this.getResultTimeline():
# 			_G = pair.first
# 			_zeta = pair.second
# 			timeline.append((Graph().setThis(_G), Partition().setThis(_zeta)))
# 		return timeline



cdef extern from "<networkit/dynamics/GraphUpdater.hpp>":

	cdef cppclass _GraphUpdater "NetworKit::GraphUpdater":
		_GraphUpdater(_Graph G) except +
		void update(vector[_GraphEvent] stream) nogil except +
		vector[pair[count, count]] getSizeTimeline() except +

cdef class GraphUpdater:
	""" Updates a graph according to a stream of graph events.

	Parameters
	----------
	G : networkit.Graph
	 	initial graph
	"""
	cdef _GraphUpdater* _this
	cdef Graph _G

	def __cinit__(self, Graph G):
		self._G = G
		self._this = new _GraphUpdater(G._this)

	def __dealloc__(self):
		del self._this

	def update(self, stream):
		cdef vector[_GraphEvent] _stream
		for ev in stream:
			_stream.push_back(_GraphEvent(ev.type, ev.u, ev.v, ev.w))
		with nogil:
			self._this.update(_stream)


# Module: coarsening

cdef extern from "<networkit/coarsening/GraphCoarsening.hpp>":

	cdef cppclass _GraphCoarsening "NetworKit::GraphCoarsening"(_Algorithm):
		_GraphCoarsening(_Graph) except +
		_Graph getCoarseGraph() except +
		vector[node] getFineToCoarseNodeMapping() except +
		map[node, vector[node]] getCoarseToFineNodeMapping() except +

cdef class GraphCoarsening(Algorithm):
	cdef Graph _G

	def __init__(self, *args, **namedargs):
		if type(self) == GraphCoarsening:
			raise RuntimeError("Error, you may not use GraphCoarsening directly, use a sub-class instead")

	def getCoarseGraph(self):
		return Graph(0).setThis((<_GraphCoarsening*>(self._this)).getCoarseGraph())

	def getFineToCoarseNodeMapping(self):
		return (<_GraphCoarsening*>(self._this)).getFineToCoarseNodeMapping()

	def getCoarseToFineNodeMapping(self):
		return (<_GraphCoarsening*>(self._this)).getCoarseToFineNodeMapping()


cdef extern from "<networkit/coarsening/ParallelPartitionCoarsening.hpp>":

	cdef cppclass _ParallelPartitionCoarsening "NetworKit::ParallelPartitionCoarsening"(_GraphCoarsening):
		_ParallelPartitionCoarsening(_Graph, _Partition, bool_t) except +


cdef class ParallelPartitionCoarsening(GraphCoarsening):
	def __cinit__(self, Graph G not None, Partition zeta not None, useGraphBuilder = True):
		self._this = new _ParallelPartitionCoarsening(G._this, zeta._this, useGraphBuilder)

cdef extern from "<networkit/coarsening/MatchingCoarsening.hpp>":

	cdef cppclass _MatchingCoarsening "NetworKit::MatchingCoarsening"(_GraphCoarsening):
		_MatchingCoarsening(_Graph, _Matching, bool_t) except +


cdef class MatchingCoarsening(GraphCoarsening):
	"""Coarsens graph according to a matching.
 	Parameters
 	----------
 	G : networkit.Graph
	M : Matching
 	noSelfLoops : bool, optional
		if true, self-loops are not produced
	"""

	def __cinit__(self, Graph G not None, Matching M not None, bool_t noSelfLoops=False):
		self._this = new _MatchingCoarsening(G._this, M._this, noSelfLoops)


# Module: scd

cdef extern from "<networkit/scd/PageRankNibble.hpp>":

	cdef cppclass _PageRankNibble "NetworKit::PageRankNibble":
		_PageRankNibble(_Graph G, double alpha, double epsilon) except +
		map[node, set[node]] run(set[node] seeds) except +

cdef class PageRankNibble:
	"""
	Produces a cut around a given seed node using the PageRank-Nibble algorithm.
	see Andersen, Chung, Lang: Local Graph Partitioning using PageRank Vectors

	Parameters:
	-----------
	G : networkit.Graph in which the cut is to be produced, must be unweighted.
	alpha : Loop probability of random walk; smaller values tend to produce larger communities.
	epsilon: Tolerance threshold for approximation of PageRank vectors
	"""
	cdef _PageRankNibble *_this
	cdef Graph _G

	def __cinit__(self, Graph G, double alpha, double epsilon):
		self._G = G
		self._this = new _PageRankNibble(G._this, alpha, epsilon)

	def run(self, set[node] seeds):
		"""
		Produces a cut around a given seed node.

		Parameters:
		-----------
		seeds : the seed node ids.
		"""
		return self._this.run(seeds)

cdef extern from "<networkit/scd/GCE.hpp>":

	cdef cppclass _GCE "NetworKit::GCE":
		_GCE(_Graph G, string quality) except +
		map[node, set[node]] run(set[node] seeds) except +

cdef class GCE:
	"""
	Produces a cut around a given seed node using the GCE algorithm.

	Parameters:
	-----------
	G : networkit.Graph in which the cut is to be produced, must be unweighted.
	"""
	cdef _GCE *_this
	cdef Graph _G

	def __cinit__(self, Graph G, quality):
		self._G = G
		self._this = new _GCE(G._this, stdstring(quality))

	def run(self, set[node] seeds):
		"""
		Produces a cut around a given seed node.

		Parameters:
		-----------
		seeds : the seed node ids.
		"""
		return self._this.run(seeds)


# Module: clique

cdef cppclass NodeVectorCallbackWrapper:
	void* callback
	__init__(object callback):
		this.callback = <void*>callback
	# This is called within the run() method which is nogil!
	void cython_call_operator(const vector[node]& nodes) nogil:
		cdef bool_t error = False
		cdef string message
		# Acquire gil to allow Python code!
		with gil:
			try:
				(<object>callback)(nodes)
			except Exception as e:
				error = True
				message = stdstring("An Exception occurred, aborting execution of iterator: {0}".format(e))
			if (error):
				throw_runtime_error(message)

cdef extern from "<networkit/clique/MaximalCliques.hpp>":

	cdef cppclass _MaximalCliques "NetworKit::MaximalCliques"(_Algorithm):
		_MaximalCliques(_Graph G, bool_t maximumOnly) except +
		_MaximalCliques(_Graph G, NodeVectorCallbackWrapper callback) except +
		vector[vector[node]] getCliques() except +

cdef class MaximalCliques(Algorithm):
	"""
	Algorithm for listing all maximal cliques.

	The implementation is based on the "hybrid" algorithm described in

	Eppstein, D., & Strash, D. (2011).
	Listing All Maximal Cliques in Large Sparse Real-World Graphs.
	In P. M. Pardalos & S. Rebennack (Eds.),
	Experimental Algorithms (pp. 364375). Springer Berlin Heidelberg.
	Retrieved from http://link.springer.com/chapter/10.1007/978-3-642-20662-7_31

	The running time of this algorithm should be in O(d^2 * n * 3^{d/3})
	where f is the degeneracy of the graph, i.e., the maximum core number.
	The running time in practive depends on the structure of the graph. In
	particular for complex networks it is usually quite fast, even graphs with
	millions of edges can usually be processed in less than a minute.

	Parameters
	----------
	G : networkit.Graph
		The graph to list the cliques for
	maximumOnly : bool
		A value of True denotes that only one maximum clique is desired. This enables
		further optimizations of the algorithm to skip smaller cliques more
		efficiently. This parameter is only considered when no callback is given.
	callback : callable
		If a callable Python object is given, it will be called once for each
		maximal clique. Then no cliques will be stored. The callback must accept
		one parameter which is a list of nodes.
	"""
	cdef NodeVectorCallbackWrapper* _callback
	cdef Graph _G
	cdef object _py_callback

	def __cinit__(self, Graph G not None, bool_t maximumOnly = False, object callback = None):
		self._G = G

		if callable(callback):
			# Make sure the callback is not de-allocated!
			self._py_callback = callback
			self._callback = new NodeVectorCallbackWrapper(callback)
			try:
				self._this = new _MaximalCliques(self._G._this, dereference(self._callback))
			except BaseException as e:
				del self._callback
				self._callback = NULL
				raise e
		else:
			self._callback = NULL
			self._this = new _MaximalCliques(self._G._this, maximumOnly)

	def __dealloc__(self):
		if not self._callback == NULL:
			del self._callback
			self._callback = NULL

	def getCliques(self):
		"""
		Return all found cliques unless a callback was given.

		This method will throw if a callback was given and thus the cliques were not stored.
		If only the maximum clique was stored, it will return exactly one clique unless the graph
		is empty.

		Returns
		-------
		A list of cliques, each being represented as a list of nodes.
		"""
		return (<_MaximalCliques*>(self._this)).getCliques()


cdef extern from "<networkit/matching/Matcher.hpp>":

	cdef cppclass _Matcher "NetworKit::Matcher"(_Algorithm):
		_Matcher(const _Graph _G) except +
		_Matching getMatching() except +

cdef class Matcher(Algorithm):
	""" Abstract base class for matching algorithms """
	cdef Graph G

	def __init__(self, *args, **namedargs):
		if type(self) == Matcher:
			raise RuntimeError("Instantiation of abstract base class")

	def getMatching(self):
		"""  Returns the matching.

		Returns
		-------
		Matching
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return Matching().setThis((<_Matcher*>(self._this)).getMatching())


cdef extern from "<networkit/matching/PathGrowingMatcher.hpp>":

	cdef cppclass _PathGrowingMatcher "NetworKit::PathGrowingMatcher"(_Matcher):
		_PathGrowingMatcher(_Graph) except +
		_PathGrowingMatcher(_Graph, vector[double]) except +

cdef class PathGrowingMatcher(Matcher):
	"""
	Path growing matching algorithm as described by  Hougardy and Drake.
	Computes an approximate maximum weight matching with guarantee 1/2.
	"""
	def __cinit__(self, Graph G not None, edgeScores=None):
		self.G = G
		if edgeScores:
			self._this = new _PathGrowingMatcher(G._this, edgeScores)
		else:
			self._this = new _PathGrowingMatcher(G._this)

# profiling

def ranked(sample):
	"""
		Given a list of numbers, this function computes the rank of each value
		and returns a list of ranks where result[i] is the rank of
		the i-th element in the given sample.
		Currently used in profiling.stat.
	"""
	cdef vector[pair[double, count]] helper = vector[pair[double, count]](len(sample))
	cdef vector[double] result = vector[double](len(sample), 0)
	for i in range(len(sample)):
		helper[i] = <pair[double, count]?>(sample[i], i)
	sort(helper.begin(), helper.end())
	cdef double value = helper[0].first
	cdef double summ = 0.
	cdef count length = 0
	for i in range(len(sample)):
		if value == helper[i].first:
			summ += (i+1)
			length += 1
		else:
			summ /= length
			for j in range(length):
				result[helper[i-j-1].second] = summ
			value = helper[i].first
			summ = i+1
			length = 1
	summ /= length
	for j in range(length):
		result[helper[len(sample)-j-1].second] = summ
	return result

def sort2(sample):
	"""
		Sorts a given list of numbers.
		Currently used as profiling.stat.sorted.
	"""
	cdef vector[double] result = <vector[double]?>sample
	sort(result.begin(),result.end())
	return result

# stats

def gini(values):
	"""
	Computes the Gini coefficient for the distribution given as a list of values.
	"""
	sorted_list = sorted(values)
	height, area = 0, 0
	for value in sorted_list:
		height += value
		area += height - value / 2.
	fair_area = height * len(values) / 2
	return (fair_area - area) / fair_area


# simulation
cdef extern from "<networkit/simulation/EpidemicSimulationSEIR.hpp>":

	cdef cppclass _EpidemicSimulationSEIR "NetworKit::EpidemicSimulationSEIR" (_Algorithm):
		_EpidemicSimulationSEIR(_Graph, count, double, count, count, node) except +
		vector[vector[count]] getData() except +

cdef class EpidemicSimulationSEIR(Algorithm):
	"""
 	Parameters
 	----------
 	G : networkit.Graph
 		The graph.
 	tMax : count
 		max. number of timesteps
	transP : double
		transmission probability
	eTime : count
		exposed time
	iTime : count
		infectious time
	zero : node
		starting node
	"""
	cdef Graph G
	def __cinit__(self, Graph G, count tMax, double transP=0.5, count eTime=2, count iTime=7, node zero=none):
		self.G = G
		self._this = new _EpidemicSimulationSEIR(G._this, tMax, transP, eTime, iTime, zero)
	def getData(self):
		return pandas.DataFrame((<_EpidemicSimulationSEIR*>(self._this)).getData(), columns=["zero", "time", "state", "count"])



## Module: viz


cdef extern from "<networkit/viz/GraphLayoutAlgorithm.hpp>":

	cdef cppclass _GraphLayoutAlgorithm "NetworKit::GraphLayoutAlgorithm"[T]:
		_GraphLayoutAlgorithm(_Graph, count) except +
		count numEdgeCrossings() except +
		vector[Point[double]] getCoordinates() except +
		bool_t writeGraphToGML(string path) except +
		bool_t writeKinemage(string path) except +

cdef class GraphLayoutAlgorithm:

	"""Abstract base class for graph drawing algorithms"""

	cdef _GraphLayoutAlgorithm[double] *_this
	cdef Graph _G

	def __init__(self, *args, **kwargs):
		if type(self) == GraphLayoutAlgorithm:
			raise RuntimeError("Error, you may not use GraphLayoutAlgorithm directly, use a sub-class instead")

	def __dealloc__(self):
		self._G = None # just to be sure the graph is deleted

	def numEdgeCrossings(self):
		""" Computes approximation (in parallel) of the Spanning Edge Centrality. """
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return self._this.numEdgeCrossings()

	def getCoordinates(self):
		""" Computes approximation (in parallel) of the Spanning Edge Centrality. """
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		cdef pair[double, double] pr = pair[double, double](0, 0)
		pointCoord = self._this.getCoordinates()
		cdef vector[pair[double, double]] pairCoord = vector[pair[double, double]]()
		for pt in pointCoord:
			pr = pair[double, double](pt[0], pt[1])
			pairCoord.push_back(pr)
		return pairCoord

	def writeGraphToGML(self, path):
		"""Writes the graph and its layout to a .gml file at the specified path
	path: string
		Path where the graph file should be created"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return self._this.writeGraphToGML(stdstring(path))

	def writeKinemage(self, string path):
		"""Writes the graph and its layout to a file at the specified path
			path: string
		Path where the graph file should be created"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return self._this.writeKinemage(stdstring(path))



cdef extern from "<networkit/viz/MaxentStress.hpp>" namespace "NetworKit":

	enum _GraphDistance "NetworKit::MaxentStress::GraphDistance":
		EDGE_WEIGHT,
		ALGEBRAIC_DISTANCE

cdef extern from "<networkit/viz/MaxentStress.hpp>" namespace "NetworKit":

	enum _LinearSolverType "NetworKit::MaxentStress::LinearSolverType":
		LAMG,
		CONJUGATE_GRADIENT_IDENTITY_PRECONDITIONER,
		CONJUGATE_GRADIENT_DIAGONAL_PRECONDITIONER


cdef extern from "<networkit/viz/MaxentStress.hpp>":

	cdef cppclass _MaxentStress "NetworKit::MaxentStress" (_GraphLayoutAlgorithm[double]):
		_MaxentStress(_Graph G, count dim, count k, double tolerance, _LinearSolverType linearSolverType, bool_t fastComputation, _GraphDistance graphDistance) except +
		_MaxentStress(_Graph G, count dim, const vector[Point[double]] coordinates, count k, double tolerance, _LinearSolverType linearSolverType, bool_t fastComputation, _GraphDistance graphDistance) except +
		void run() except +
		void scaleLayout() except +
		double computeScalingFactor() except +
		double fullStressMeasure() except +
		double maxentMeasure() except +
		double meanDistanceError() except +
		double ldme() except +
		void setQ(double q) except +
		void setAlpha(double alpha) except +
		void setAlphaReduction(double alphaReduction) except +
		void setFinalAlpha(double finalAlpha) except +
		void setConvergenceThreshold(double convThreshold) except +
		double getRhs() except +
		double getApproxEntropyTerm() except +
		double getSolveTime() except +


cdef class MaxentStress (GraphLayoutAlgorithm):

	"""
	Implementation of MaxentStress by Gansner et al. using a Laplacian system solver.
  	@see Gansner, Emden R., Yifan Hu, and Steve North. "A maxent-stress model for graph layout."
	Visualization and Computer Graphics, IEEE Transactions on 19, no. 6 (2013): 927-940.

	Parameters
	----------
	G : networkit.Graph
		The graph to be handled. Should be connected, otherwise the run() and runAlgo() methods will fail.
	dim: count
		Number of dimensions.
	count: k
	coordinates: vector[pair[double, double]]
		The coordinates we want to draw in.
	tolerance: double
		The tolerance we want our solver to have.
	linearSolverType: _LinearSolverType
		The type of linear solver we wish to use.
	fastComputation: bool
		Decides whether or not slightly faster computation should be employed, leading to slightly worse results.
	graphDistance: _GraphDistance
		Decides what type of graph distance should be utilised.
	"""

	LAMG = 0
	CONJUGATE_GRADIENT_IDENTITY_PRECONDITIONER = 1
	CONJUGATE_GRADIENT_DIAGONAL_PRECONDITIONER = 2
	EDGE_WEIGHT = 0
	ALGEBRAIC_DISTANCE = 1

	def __cinit__(self, Graph G, count dim, count k, vector[pair[double, double]] coordinates = [], double tolerance = 1e-5, _LinearSolverType linearSolverType = LAMG, bool_t fastComputation = False, _GraphDistance graphDistance = EDGE_WEIGHT):
		cdef Point[double] p = Point[double](0, 0)
		cdef vector[Point[double]] pointCoordinates = vector[Point[double]]()

		for pr in coordinates:
			p = Point[double](pr.first, pr.second)
			pointCoordinates.push_back(p)

		if (coordinates.size() != 0):
			self._this = new _MaxentStress(G._this, dim, pointCoordinates, k, tolerance, linearSolverType, fastComputation, graphDistance)
		else:
			self._this = new _MaxentStress(G._this, dim, k, tolerance, linearSolverType, fastComputation, graphDistance)

	def __dealloc__(self):
		del self._this

	def run(self):
		"""Approximates a graph layout with the maxent-stress algorithm"""
		(<_MaxentStress*>(self._this)).run()
		return self

	def scaleLayout(self):
		"""Scale the layout computed by run() by a scalar s to minimize \sum_{u,v \in V} w_{uv} (s ||x_u - x_v|| - d_{uv}||)^2"""
		(<_MaxentStress*>(self._this)).scaleLayout()
		return self

	def computeScalingFactor(self):
		"""Computes a scalar s s.t. \sum_{u,v \in V} w_{uv} (s ||x_u - x_v|| - d_{uv}||)^2 is minimized"""
		return (<_MaxentStress*>(self._this)).computeScalingFactor()

	def fullStressMeasure(self):
		"""Computes the full stress measure of the computed layout with run()"""
		return (<_MaxentStress*>(self._this)).fullStressMeasure()

	def maxentMeasure(self):
		"""Computes the maxent stress measure for the computed layout with run()"""
		return (<_MaxentStress*>(self._this)).maxentMeasure()

	def meanDistanceError(self):
		"""Computes mean distance error"""
		return (<_MaxentStress*>(self._this)).meanDistanceError()

	def ldme(self):
		"""Computes the ldme"""
		return (<_MaxentStress*>(self._this)).ldme()

	def setQ(self, double q):
		(<_MaxentStress*>(self._this)).setQ(q)
		return self

	def setAlpha(self, double alpha):
		(<_MaxentStress*>(self._this)).setAlpha(alpha)
		return self

	def setAlphaReduction(self, double alphaReduction):
		(<_MaxentStress*>(self._this)).setAlphaReduction(alphaReduction)
		return self

	def setFinalAlpha(self, double finalAlpha):
		(<_MaxentStress*>(self._this)).setFinalAlpha(finalAlpha)
		return self

	def setConvergenceThreshold(self, double convThreshold):
		(<_MaxentStress*>(self._this)).setConvergenceThreshold(convThreshold)
		return self

	def getRhs(self):
		return (<_MaxentStress*>(self._this)).getRhs()

	def getApproxEntropyTerm(self):
		return (<_MaxentStress*>(self._this)).getApproxEntropyTerm()

	def getSolveTime(self):
		return (<_MaxentStress*>(self._this)).getSolveTime()





cdef extern from "<networkit/viz/PivotMDS.hpp>":

	cdef cppclass _PivotMDS "NetworKit::PivotMDS" (_GraphLayoutAlgorithm[double]):
				_PivotMDS(_Graph G, count dim, count numberOfPivots) except +
				void run() except +


cdef class PivotMDS (GraphLayoutAlgorithm):

	"""
	Implementation of PivotMDS proposed by Brandes and Pich.

	Parameters
	----------

	G: networkit.Graph
		The graph to be handled by the algorithm.

	dim: count
		Number of dimensions.

	numberOfPivots: count
		Number of pivots for the algorithm.

	"""

	def __cinit__(self, Graph G, count dim, count numberOfPivots):
		self._this = new _PivotMDS(G._this, dim, numberOfPivots)

	def __dealloc__(self):
		del self._this

	def run(self):
		"""Constructs a PivotMDS object for the given @a graph. The algorithm should embed the graph in @a dim dimensions using @a numberOfPivots pivots."""
		(<_PivotMDS*>(self._this)).run()
		return self

