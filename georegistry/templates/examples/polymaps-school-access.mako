<%inherit file='/examples/base.mako'/>

<%def name='title()'>Polymaps</%def>

<%def name='head()'>
${h.javascript_link('/files/polymaps.min.js')}
${h.stylesheet_link('/files/colorbrewer.css')}
</%def>

<%def name='navigation()'>
<br>
Maximum distance to facility in meters <input size=5 value=2000 id=accessDistance> <input type=button value=Filter id=accessFilter>
<ul>
    <li>Here is a heatmap of households that are farther than two kilometers from a school in Ruhiira, Uganda.</li>
    <li><a class=linkOFF href='/examples/polymaps-household-density'>Click here to see a heatmap of household density.</a></li>
    <li>Click on schools in the map or table to see their details.</li>
</ul>
</%def>

<%def name='css()'>
    .compass .back {fill: #eee; fill-opacity: .8}
    .compass .fore {stroke: #999; stroke-width: 1.5px}
    .compass rect.back.fore {fill: #999; fill-opacity: .3; stroke: #eee; stroke-width: 1px; shape-rendering: crispEdges} 
    .compass .direction {fill: none}
    .compass .chevron {fill: none; stroke: #999; stroke-width: 5px}
    .compass .zoom .chevron {stroke-width: 4px} 
    .compass .active .chevron, .compass .chevron.active {stroke: #fff}
    .compass.active .active .direction {fill: #999}
    #features {fill-opacity: 0.5}
    .feature_school {fill: yellow}
    .feature_house0 {fill: red}
    .feature_house1 {fill: green}
</%def>

<%def name='js()'>
    function includeTag(tag) {
        if (tag.search(/Uganda Ruhiira/) == 0) return true;
        if (tag.search(/Uganda Administrative Level 4/) == 0) return true;
    }
    function activateTag(tag) {
        if (tag.search(/Uganda Ruhiira Schools/) == 0) return true;
    }
    var propertyByNameByID = {}, elementsByID = {}, geometriesByID = {};
    function renderMaps() {
        // Load
        var tagString = getSelectedTags();
        // Clean
        if (layer) map.remove(layer);
        if (!tagString) return;
        layer = po.geoJson().url('${h.url("map_view_", responseFormat="json")}?key=' + $('#key').val() + '&srid=4326&tags=' + escape(tagString) + "&bboxFormat=xyxy&bbox={B}&simplified=1").id('features').on('load', function(e) {
            // For each feature,
            $(e.features).each(function() {
                // Load
                var featureID = this.data.id;
                // Store propertyByName
                propertyByNameByID[featureID] = this.data.properties;
                // Store element
                if (!elementsByID[featureID]) elementsByID[featureID] = []
                elementsByID[featureID].push(this.element);
                // Store geometry
                if (!geometriesByID[featureID]) geometriesByID[featureID] = []
                geometriesByID[featureID].push(this.data.geometry);
                // Set hover listener
                var element = this.element;
                element.addEventListener('mouseover', getHoverFeature(featureID), false);
                element.addEventListener('mouseout', getUnhoverFeature(featureID), false);
                // Set click listener
                element.addEventListener('click', getSelectFeature(featureID), false);
                // Set id
                element.setAttribute('id', 'e' + featureID);
                // Set color class
                restoreFeatureColor(featureID);
            });
            // Initialize
            var items = [];
            // For each stored feature,
            for (featureID in propertyByNameByID) {
                // If the feature is visible,
                if ($('#e' + featureID).length) {
                    propertyByName = propertyByNameByID[featureID];
                    items.push({
                        featureID: featureID,
                        name: propertyByName['Name'] || featureID + ''
                    });
                } 
                // If the feature is not visible,
                else {
                    delete propertyByNameByID[featureID];
                }
            }
            // Sort
            items.sort(compareByName);
            // Display
            var listLines = [];
            $(items).each(function() {
                listLines.push('<div class="fN feature" id=d' + this.featureID + '>' + this.name + '</div>');
            });
            $('#list').html(listLines.join('\n'));
            $('#list .feature').hover(
                function () {
                    scrollList = 0;
                    getHoverFeature(getID(this))();
                    scrollList = 1;
                }, 
                function () {
                    scrollList = 0;
                    getUnhoverFeature(getID(this))();
                    scrollList = 1;
                }
            ).click(function() {
                getSelectFeature(getID(this))();
            });
        });
        map.add(layer);
    }

    // Define factories
    var scrollList = 1;
    function getHoverFeature(featureID) {
        return function(e) {
            // Highlight list entry
            var listHover = $('#d' + featureID);
            listHover.removeClass('bN bS').addClass('bH');
            if (scrollList) {
                // Scroll list
                var list = $('#list');
                list.scrollTop(list.scrollTop() + listHover.position().top - list.height() / 2);
            }
            // Highlight map entry
            setFeatureColor(featureID, 'fH');
        };
    }
    function getUnhoverFeature(featureID) {
        return function(e) {
            // Restore list entry
            var listHover = $('#d' + featureID);
            listHover.removeClass('bH bS').addClass('bN');
            // Restore map entry
            restoreFeatureColor(featureID);
        }
    }
    function getSelectFeature(featureID) {
        return function(e) {
            if (selectedID && selectedID != featureID) {
                // Restore list entry
                var listSelect = $('#d' + selectedID);
                if (listSelect) listSelect.removeClass('bH bS').addClass('bN');
                // Restore map entry
                restoreFeatureColor(featureID);
            }
            // Load
            selectedID = featureID;
            // Highlight list entry
            var listSelect = $('#d' + selectedID);
            listSelect.removeClass('bN bH').addClass('bS');
            // Highlight map entry
            setFeatureColor(selectedID, 'fS');
            // Set feature detail
            var propertyByName = propertyByNameByID[selectedID], propertyLines = [];
            for (key in propertyByName) {
                propertyLines.push(key + ' = ' + propertyByName[key]);
            }
            propertyLines.sort();
            $('#detail').html('<div id=detailHeader>' + propertyByName['Name'] + '</div><br>' + propertyLines.join('<br>'));
        };
    }
    function getColorClass(featureID) {
        return 'q' + (8 - (featureID % 9)) + '-' + 9;
    }
    function setFeatureColor(featureID, colorClass) {
        $(elementsByID[featureID]).each(function() {
            this.setAttribute('class', colorClass);
        });
    }
    function restoreFeatureColor(featureID) {
        $(elementsByID[featureID]).each(function() {
            if (this.nodeName == 'circle') {
                // Not efficient at all, of course
                if (propertyByNameByID[featureID] && propertyByNameByID[featureID]['Type'] == 'Education') {
                    this.setAttribute('class', 'feature_school');
                    this.setAttribute('r', '10');
                } else {
                    this.setAttribute('class', getColorClass(featureID));
                }
            } else {
                this.setAttribute('class', getColorClass(featureID));
            }
        });
    }

    // Make map using Polymaps
// .add(po.image().url(po.url('http://{S}tile.cloudmade.com/8f066e8fa23c4e0abb89650a38555a58/20760/256/{Z}/{X}/{Y}.png').hosts(['a.', 'b.', 'c.', ''])))
// .add(po.image().url(po.url('http://{S}tile.cloudmade.com/8f066e8fa23c4e0abb89650a38555a58/998/256/{Z}/{X}/{Y}.png').hosts(['a.', 'b.', 'c.', ''])))
        // .add(po.image().url(po.url('http://khm{S}.googleapis.com/kh?v=78&x={X}&y={Y}&z={Z}').hosts(['0', '1', '2', '3', ''])))
    var po = org.polymaps;
    map = po.map()
        .container(document.getElementById('map').appendChild(po.svg('svg')))
        .center({lon: 30.66002, lat: -0.88977})
        .zoom(13)
        .add(po.image().url(po.url('http://{S}tile.cloudmade.com/8f066e8fa23c4e0abb89650a38555a58/20760/256/{Z}/{X}/{Y}.png').hosts(['a.', 'b.', 'c.', ''])))
        .add(po.interact())
        .add(po.compass().pan('none'));
    map.container().setAttribute('class', 'OrRd');
    var selectedID;
    $('#detail').hover(
        function() {
            if (selectedID) {
                $(this).css('background-color', '#b2b2b2');
            }
        },
        function() {
            $(this).css('background-color', '#cccccc');
        }
    ).click(function() {
        if (selectedID) {
            // Initialize
            var mapExtent = map.extent(), mapLL = mapExtent[0], mapUR = mapExtent[1];
            var minLon = mapUR.lon, minLat = mapUR.lat, maxLon = mapLL.lon, maxLat = mapLL.lat;
            var geometries = geometriesByID[selectedID];
            var queue = [];
            for (var i = 0; i < geometries.length; i++) {
                queue.push(geometries[i].coordinates);
            }
            while (queue.length) {
                var object = queue.pop();
                if (typeof object[0] == 'number') {
                    var lon = object[0], lat = object[1];
                    if (lon < minLon) minLon = lon;
                    if (lon > maxLon) maxLon = lon;
                    if (lat < minLat) minLat = lat;
                    if (lat > maxLat) maxLat = lat;
                } else {
                    for (var i = 0; i < object.length; i++) {
                        queue.push(object[i]);
                    }
                }
            }
            // Scale to include more background
            var scalingFactor = 1.2;
            var xLengthHalved = (maxLon - minLon) / 2;
            var yLengthHalved = (maxLat - minLat) / 2;
            // Zoom to scaled feature extent
            map.extent([{
                lon: minLon + (1 - scalingFactor) * xLengthHalved,
                lat: minLat + (1 - scalingFactor) * yLengthHalved
            }, {
                lon: minLon + (1 + scalingFactor) * xLengthHalved,
                lat: minLat + (1 + scalingFactor) * yLengthHalved
            }]);
        }
    });



    map.add(po.layer(function(tile, proj) {
        proj = proj(tile);
        var tl = proj.locationPoint({lon: 30.588140726617, lat: -0.80146479432311}), br = proj.locationPoint({lon: 30.7376316188356, lat: -0.978387419713273}), image = tile.element = po.svg('image');
        image.setAttribute('preserveAspectRatio', 'none');
        image.setAttribute('x', tl.x);
        image.setAttribute('y', tl.y);
        image.setAttribute('width', br.x - tl.x);
        image.setAttribute('height', br.y - tl.y);
        image.setAttributeNS('http://www.w3.org/1999/xlink', 'href', '/examples/uganda-ruhiira-school-access.png');
    }).tile(false));
    var populationCenterByFeatureID = {};
    map.add(po.geoJson().url('/examples/polymaps-school-filter').on('load', function(e) {
        $(e.features).each(function() {
            // Load
            var featureID = this.data.id;
            populationCenterByFeatureID[featureID] = {
                element: this.element,
                distance: this.data.properties['d']
            }
        })
        colorPopulationCenters();
    }));

    function colorPopulationCenters() {
        var accessDistance = $('#accessDistance').val();
        $.each(populationCenterByFeatureID, function(key, value) {
            var element = value.element;
            var distance = value.distance;
            if (distance > accessDistance) {
                element.setAttribute('class', 'feature_house0');
            } else {
                element.setAttribute('class', 'feature_house1');
            }
        });
    }
    $('#accessFilter').click(colorPopulationCenters);
</%def>
