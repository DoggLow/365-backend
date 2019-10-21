// const values for styling
var userIcon = "m16.008 16.953c3.9609 0 7.1758-3.7617 7.1758-8.4023 0-6.4336-3.2148-8.4023-7.1758-8.4023-3.9648 0-7.1797 1.9688-7.1797 8.4023 0 4.6406 3.2148 8.4023 7.1797 8.4023zm15.848 12.363l-3.6211-8.1562c-0.16406-0.375-0.45703-0.68359-0.81641-0.87109l-5.6211-2.9258c-0.125-0.0625-0.27344-0.050781-0.38672 0.03125-1.5898 1.2031-3.457 1.8398-5.4023 1.8398-1.9492 0-3.8164-0.63672-5.4062-1.8398-0.11328-0.082031-0.26172-0.09375-0.38672-0.03125l-5.6172 2.9258c-0.36328 0.1875-0.65234 0.49609-0.82031 0.87109l-3.6211 8.1562c-0.25 0.5625-0.19922 1.207 0.13672 1.7227 0.33594 0.51563 0.90234 0.82422 1.5195 0.82422h28.391c0.61328 0 1.1797-0.30859 1.5156-0.82422 0.33594-0.51562 0.38672-1.1602 0.13672-1.7227z";
var openedColor = '#bcbcbc';
var closedColor = '#fff';
var tipStartX = 20;
var tipStartY = -20;
var tipDY = 12;
var tipWidth = 100;
var tipHeight = 14;
var nodeDY = 64;

// get data from controller(view)
treeEl = document.getElementById('tree');
treeData = treeEl.getAttribute("data-tree");
flatData = JSON.parse(treeData);

// convert the flat data into a hierarchy
var treeData = d3.stratify()
    .id(function(d) { return d.child; })
    .parentId(function(d) { return d.parent; })
    (flatData);

// ************** Generate the tree diagram	 *****************

// Set the dimensions and margins of the diagram
var margin = {top: 40, right: 80, bottom: 40, left: 80},
    width = 1040,
    height = 500;

// append the svg object to the body of the page
// appends a 'group' element to 'svg'
// moves the 'group' element to the top left margin
var svg = d3.select("#tree").append("svg")
    .attr("width", '100%')
    .attr("height", height + margin.top + margin.bottom)
    .append("g")
    .attr("transform", "translate("
        + width/4 + "," + margin.top + ")");

var i = 0,
    duration = 500,
    root;

// declares a tree layout and assigns the size
var treemap = d3.tree().size([height, width]);

// Assigns parent, children, height, depth
root = d3.hierarchy(treeData, function(d) { return d.children; });
root.x0 = 0;
root.y0 = height / 2;

// Collapse after the second level
root.children.forEach(collapse);

update(root);

// Collapse the node and all it's children
function collapse(d) {
    if(d.children) {
        d._children = d.children
        d._children.forEach(collapse)
        d.children = null
    }
}

function update(source) {

    // Assigns the x and y position for the nodes
    var treeData = treemap(root);

    // Compute the new tree layout.
    var nodes = treeData.descendants(),
        links = treeData.descendants().slice(1);

    // Normalize for fixed-depth.
    nodes.forEach(function(d){ d.y = d.depth * nodeDY});

    // ****************** Nodes section ***************************

    // Update the nodes...
    var node = svg.selectAll('g.node')
        .data(nodes, function(d) {return d.id || (d.id = ++i); });

    // Enter any new modes at the parent's previous position.
    var nodeEnter = node.enter().append('g')
        .attr('class', 'node')
        .attr("transform", function(d) {
            return "translate(" + source.x0 + "," + source.y0 + ")";
        })
        .on('click', onClick)
        .on("mouseover", onMouseOver)
        .on("mouseout", onMouseOut);

    // Add Icon for the nodes
    nodeEnter.append('path')
        .attr('class', 'node')
        .attr('d', userIcon)
        .style("fill", function(d) {
            return d._children ? openedColor : closedColor;
        })
        .attr("transform", function(d) {
            return "translate(-16, -24)";
        });

    // Add labels for the nodes
    nodeEnter.append('text')
        .attr("x", 0)
        .attr("y", 20)
        .attr("text-anchor", "middle")
        .text(function(d) { return d.data.data.child; });

    // UPDATE
    var nodeUpdate = nodeEnter.merge(node);

    // Transition to the proper position for the node
    nodeUpdate.transition()
        .duration(duration)
        .attr("transform", function(d) {
            return "translate(" + d.x + "," + d.y + ")";
        });

    // Update the node attributes and style
    nodeUpdate.select('path.node')
        .attr('d', userIcon)
        .style("fill", function(d) {
            return d._children ? openedColor : closedColor;
        })
        .attr('cursor', 'pointer');


    // Remove any exiting nodes
    var nodeExit = node.exit().transition()
        .duration(duration)
        .attr("transform", function(d) {
            return "translate(" + source.x + "," + source.y + ")";
        })
        .remove();

    // On exit reduce the node icon size to 0
    nodeExit.select('path')
        .attr('d', null);

    // On exit reduce the opacity of text labels
    nodeExit.select('text')
        .style('fill-opacity', 1e-6);

    // ****************** links section ***************************

    // Update the links...
    var link = svg.selectAll('path.link')
        .data(links, function(d) { return d.id; });

    // Enter any new links at the parent's previous position.
    var linkEnter = link.enter().insert('path', "g")
        .attr("class", "link")
        .attr('d', function(d){
            var o = {x: source.x0, y: source.y0}
            return diagonal(o, o)
        });

    // UPDATE
    var linkUpdate = linkEnter.merge(link);

    // Transition back to the parent element position
    linkUpdate.transition()
        .duration(duration)
        .attr('d', function(d){ return diagonal(d, d.parent) });

    // Remove any exiting links
    var linkExit = link.exit().transition()
        .duration(duration)
        .attr('d', function(d) {
            var o = {x: source.x, y: source.y}
            return diagonal(o, o)
        })
        .remove();

    // Store the old positions for transition.
    nodes.forEach(function(d){
        d.x0 = d.x;
        d.y0 = d.y;
    });

    // Creates a curved (diagonal) path from parent to the child nodes
    function diagonal(s, d) {
        return "M" + s.x + "," + s.y
            + "C" + s.x + "," + (d.y + s.y) / 2
            + " " + d.x + "," +  (d.y + s.y) / 2
            + " " + d.x + "," + d.y;
    }

    // Toggle children on click.
    function onClick(d) {
        if (d.children) {
            d._children = d.children;
            d.children = null;
        } else {
            d.children = d._children;
            d._children = null;
        }
        update(d);
    }

    // Toggle on MouseOver.
    function onMouseOver(d) {
        //added mouseover function
        var g = d3.select(this); // The node
        // The class is used to remove the additional text later
        var attributes = d.data.data.attributes;
        var x = tipStartX;
        var y = tipStartY;
        g.append('text')
            .classed('info', true)
            .attr('x', x)
            .attr('y', y)
            .text('TIER: ' + d.data.depth);
        for (var key in attributes) {
            if (attributes.hasOwnProperty(key)) {
                g.append('rect') // text background
                    .classed('bound', true)
                    .attr('x', x-4)
                    .attr('y', y)
                    .attr('width', tipWidth)
                    .attr('height', tipHeight);
                y += tipDY;
                g.append('text') // text for attributes
                    .classed('info', true)
                    .attr('x', x)
                    .attr('y', y)
                    .text(key + ': ' +attributes[key]);
            }
        }
    }
    // Toggle on MouseOut.
    function onMouseOut(d) {
        // Remove the info text on mouse out.
        d3.select(this).selectAll('text.info').remove();
        d3.select(this).selectAll('rect.bound').remove();
    }
}
