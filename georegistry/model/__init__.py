'Database objects'
# Import system modules
import sqlalchemy as sa
import sqlalchemy.orm as orm
import hashlib
import geoalchemy
import geoalchemy.postgis
import shapely.wkb
# Import custom modules
from georegistry.model.meta import Session, Base
from georegistry.config import parameter


# Methods

def init_model(engine):
    'Call me before using any of the tables or classes in the model'
    Session.configure(bind=engine)

def hashString(string): 
    'Compute the hash of the string'
    return hashlib.sha256(string).digest()


# Tables

people_table = sa.Table('people', Base.metadata,
    sa.Column('id', sa.Integer, primary_key=True),
    sa.Column('username', sa.String(parameter.USERNAME_LENGTH_MAXIMUM), unique=True, nullable=False),
    sa.Column('password_hash', sa.LargeBinary(32), nullable=False),
    sa.Column('nickname', sa.Unicode(parameter.NICKNAME_LENGTH_MAXIMUM), unique=True, nullable=False),
    sa.Column('email', sa.String(parameter.EMAIL_LENGTH_MAXIMUM), unique=True, nullable=False),
    sa.Column('minutes_offset', sa.Integer, default=0),
    sa.Column('rejection_count', sa.Integer, default=0),
    sa.Column('is_super', sa.Boolean, default=False),
)
person_candidates_table = sa.Table('person_candidates', Base.metadata,
    sa.Column('id', sa.Integer, primary_key=True),
    sa.Column('username', sa.String(parameter.USERNAME_LENGTH_MAXIMUM), nullable=False),
    sa.Column('password_hash', sa.LargeBinary(32), nullable=False),
    sa.Column('nickname', sa.Unicode(parameter.NICKNAME_LENGTH_MAXIMUM), nullable=False),
    sa.Column('email', sa.String(parameter.EMAIL_LENGTH_MAXIMUM), nullable=False),
    sa.Column('person_id', sa.ForeignKey('people.id')),
    sa.Column('ticket', sa.String(parameter.TICKET_LENGTH), unique=True, nullable=False),
    sa.Column('when_expired', sa.DateTime, nullable=False),
)
sms_addresses_table = sa.Table('sms_addresses', Base.metadata,
    sa.Column('id', sa.Integer, primary_key=True),
    sa.Column('email', sa.String(parameter.EMAIL_LENGTH_MAXIMUM), unique=True, nullable=False),
    sa.Column('owner_id', sa.ForeignKey('people.id')),
    sa.Column('is_active', sa.Boolean, default=False),
)
countries_table = sa.Table('countries', Base.metadata,
    sa.Column('id', sa.Integer, primary_key=True),
    sa.Column('name', sa.String(parameter.COUNTRY_NAME_LENGTH_MAXIMUM), nullable=False),
    sa.Column('code_alpha2', sa.String(2), nullable=False),
    sa.Column('code_alpha3', sa.String(3), nullable=False),
    geoalchemy.GeometryExtensionColumn('center', geoalchemy.Point(srid=900913)),
    geoalchemy.GeometryExtensionColumn('bound_lb', geoalchemy.Point(srid=900913)),
    geoalchemy.GeometryExtensionColumn('bound_rt', geoalchemy.Point(srid=900913)),
)
regions_table = sa.Table('regions', Base.metadata,
    sa.Column('id', sa.Integer, primary_key=True),
    geoalchemy.GeometryExtensionColumn('geometry', geoalchemy.Geometry(srid=900913), nullable=False),
    sa.Column('country_id', sa.ForeignKey('countries.id')),
    sa.Column('level', sa.Integer, nullable=False),
)


# Classes

class Person(object):

    def __init__(self, username, password_hash, nickname, email):
        self.username = username
        self.password_hash = password_hash
        self.nickname = nickname
        self.email = email

    def __repr__(self):
        return "<Person('%s')>" % self.email


class PersonCandidate(Person):

    def __repr__(self):
        return "<PersonCandidate('%s')>" % self.email


class SMSAddress(object):

    def __init__(self, email, owner_id):
        self.email = email
        self.owner_id = owner_id

    def __repr__(self):
        return "<SMSAddress('%s')>" % self.email


class LowerCaseComparator(orm.properties.ColumnProperty.Comparator):

    def __eq__(self, other):
        return sa.func.lower(self.__clause_element__()) == sa.func.lower(other)


class Country(object):

    def __init__(self, name, code_alpha2, code_alpha3):
        self.name = name
        self.code_alpha2 = code_alpha2
        self.code_alpha3 = code_alpha3

    def getCenter(self):
        center = shapely.wkb.loads(str(self.center.geom_wkb))
        return center.x, center.y

    def getBox(self):
        bound_lb = shapely.wkb.loads(str(self.bound_lb.geom_wkb))
        bound_rt = shapely.wkb.loads(str(self.bound_rt.geom_wkb))
        return bound_lb.x, bound_lb.y, bound_rt.x, bound_rt.y


class Region(object):

    def __init__(self, geometry, country_id, level):
        self.geometry = geometry
        self.country_id = country_id
        self.level = level


# Links

orm.mapper(Person, people_table, properties={
    'username': orm.column_property(people_table.c.username, comparator_factory=LowerCaseComparator),
    'nickname': orm.column_property(people_table.c.nickname, comparator_factory=LowerCaseComparator),
    'email': orm.column_property(people_table.c.email, comparator_factory=LowerCaseComparator),
    'sms_addresses': orm.relation(SMSAddress),
})
orm.mapper(PersonCandidate, person_candidates_table, properties={
    'username': orm.column_property(person_candidates_table.c.username, comparator_factory=LowerCaseComparator),
    'nickname': orm.column_property(person_candidates_table.c.nickname, comparator_factory=LowerCaseComparator),
    'email': orm.column_property(person_candidates_table.c.email, comparator_factory=LowerCaseComparator),
})
orm.mapper(SMSAddress, sms_addresses_table, properties={
    'email': orm.column_property(sms_addresses_table.c.email, comparator_factory=LowerCaseComparator),
})
orm.mapper(Country, countries_table, properties={
    'regions': orm.relation(Region, backref='country'),
    'center': geoalchemy.GeometryColumn(countries_table.c.center, comparator=geoalchemy.postgis.PGComparator),
    'bound_lb': geoalchemy.GeometryColumn(countries_table.c.bound_lb, comparator=geoalchemy.postgis.PGComparator),
    'bound_rt': geoalchemy.GeometryColumn(countries_table.c.bound_rt, comparator=geoalchemy.postgis.PGComparator),
})
orm.mapper(Region, regions_table, properties={
    'geometry': geoalchemy.GeometryColumn(regions_table.c.geometry, comparator=geoalchemy.postgis.PGComparator),
})


# Set DDLs
geoalchemy.GeometryDDL(countries_table)
geoalchemy.GeometryDDL(regions_table)
