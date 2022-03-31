# spring-boot-postgres-fts
demo project with spring boot, jooq and postgres full text search


## Setup

- start the DB - ``docker compose up -d``
- build the project - ``./mvnw verify``

The DB is accessible under localhost:4242
- user: fts-ftw
- PW: fts-ftw
- DB & schema: fts-ftw

The DB contains some example data, the European CPV codes in D/F/I/E.

The spring app runs under the default localhost:8080
and exposes the following endpoints:

```http request
# treverst the CPV code tree 

### get root nodes
GET http://localhost:8080/api/cpv-codes

### get next lvl, set the id of the parent as query
GET http://localhost:8080/api/cpv-codes?parent=ID

# search thru the codes 

### Use the FTS search over all language will use the `simple` postgres config
GET http://localhost:8080/api/cpv-codes/search?query=TXTX

### Use the FTS search over all language will use the postgres config for the given language
GET http://localhost:8080/api/cpv-codes/search?query=TXTX&language=en
```
  
UNDER CONSTRUCTION$

![UNDER CONSTRUCTION](https://media.giphy.com/media/ZTans30ONaaIM/giphy.gif)
