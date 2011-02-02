'Examples controller'
# Import pylons modules
from pylons import request, response, session, tmpl_context as c, url
from pylons.controllers.util import abort, redirect
# Import system modules
import sqlalchemy as sa
import geojson
from sqlalchemy import orm
import shapely.wkb
# Import custom modules
from georegistry.lib.base import BaseController, render
from georegistry import model
from georegistry.model import Session


class ExamplesController(BaseController):

    def openlayers(self):
        return render('/examples/openlayers.mako')

    def polymaps(self):
        return render('/examples/polymaps.mako')

    def polymaps_school_access(self):
        return render('/examples/polymaps-school-access.mako')

    def polymaps_school_filter(self):
        FeatureAlias = orm.aliased(model.Feature)
        schoolIDs = [x[0] for x in Session.query(model.Feature.id).join(model.Feature.tags).filter(model.Tag.text==u'Uganda Ruhiira Schools')]
        statement = Session.query(model.Feature.id.label('feature_id'), sa.func.min(model.Feature.geometry.transform(3857).distance(FeatureAlias.geometry.transform(3857))).label('minimum_distance')).join(model.Feature.tags).filter(model.Tag.text==u'Uganda Ruhiira Population Centers').filter(FeatureAlias.id.in_(schoolIDs)).group_by(model.Feature.id).subquery()
        featurePacks = Session.query(model.Feature.id, model.Feature.geometry.transform(4326).wkb, statement.c.minimum_distance).join((statement, model.Feature.id==statement.c.feature_id)).all()
        return geojson.dumps(geojson.FeatureCollection([(geojson.Feature(id=featureID, geometry=shapely.wkb.loads(str(featureWKB)), properties={'d': int(featureDistance)})) for featureID, featureWKB, featureDistance in featurePacks]))

    def polymaps_household_density(self):
        return render('/examples/polymaps-household-density.mako')
