angular-indexed-db
=================

![build status](https://circleci.com/gh/bramski/angular-indexedDB.png?circle-token=:circle-token)

An AngularJS service provider to utilize indexedDB with angular

##Release Notes
### 1.1.1
  Bugfix release.  Addresses a problem with opening multiple stores and a problem with
  using this library in non-native indexedDB environments.

### 1.1.0
  Lots of changes.  The way of interacting with stores has changed so that you can operate
  more transaction-aware.  Many things did not work in the prior version correctly.
  The service is now well tested and the base build is written in coffeescript.

## Installation

For installation the use of Bower is recommended.

### Bower
Call the following command on your command line:

```sh
bower install --save angular-indexed-db
```

And add the following line to your html file, for example `index.html`:

```html
<script src="components/angular-indexed-db/angular-indexed-db.js"></script>
```


### Manual

- Download file.
- Add the following line to your html file:

```html
<script src="angular-indexed-db.js"></script>
```

## Usage

Normally, and as a recommendation, you have only one indexedDB per app.
Thus in your `app.js` where you define your module, you do:

```javascript
angular.module('myModuleName', ['indexedDB'])
  .config(function ($indexedDBProvider) {
    $indexedDBProvider
      .connection('myIndexedDB')
      .upgradeDatabase(1, function(event, db, tx){
        var objStore = db.createObjectStore('people', {keyPath: 'ssn'});
        objStore.createIndex('name_idx', 'name', {unique: false});
        objStore.createIndex('age_idx', 'age', {unique: false});
      });
  });
```
The connection method takes the databasename as parameter,
the upgradeCallback has 3 parameters:
function callback(event, database, transaction). AngularJS-indexedDB supports incremental
upgrades.  Simply define what to do for each version incrementally:
```javascript
angular.module('myModuleName', ['indexedDB'])
  .config(function ($indexedDBProvider) {
    $indexedDBProvider
      .connection('myIndexedDB')
      .upgradeDatabase(1, function(event, db, tx){
        var objStore = db.createObjectStore('people', {keyPath: 'ssn'});
        objStore.createIndex('name_idx', 'name', {unique: false});
        objStore.createIndex('age_idx', 'age', {unique: false});
      });
      .upgradeDatabase(2, function(event, db, tx){
        db.createObjectStore('peoplePhones', {keyPath: 'person_ssn'});
      });
  });
```
When upgrade is required only the migrations which have not been run yet will be run.
For upgrading your db structure, see 
https://developer.mozilla.org/en-US/docs/IndexedDB/Using_IndexedDB.

You can also define your own error handlers, overwriting the default ones, which log to console.


Inside your controller you use `$indexedDB` like this:

```javascript
angular.module('myModuleName')
  .controller('myControllerName', function($scope, $indexedDB) {
    
    $scope.objects = [];
        
    $indexedDB.openStore('people', function(store) {
    
      store.insert({"ssn": "444-444-222-111","name": "John Doe", "age": 57}).then(function(e){...});
    
      store.getAll().then(function(people) {  
        // Update scope
        $scope.objects = people;
      });

    });
  })
```

## openStore

When you open a store a transaction is created for all of your actions against that store
you receive a promise for each operation within your transaction and also for the transaction
as a whole as the result of "openStore".  The transaction resolves successfully after state
has been fully persisted.

## store operations

The following operations are allowed on a store..

* getAllKeys - Returns all the primary keys on the store
* clear - Deletes all items from the store
* delete - Deletes a single item from the store
* upsert - Upserts an item or list of items in the store
* insert - Inserts an item or list of items in the store
* getAll - Returns all items in the store
* each - iterates over all items in the store
* eachBy - iterates over all items in the store using a named index.
* eachWhere - uses the query() to execute a find against the store
* findWhere - an alias for eachWhere
* count - returns a count of all the items
* find - returns a single item from the store
* findBy - searches a particular index for an item
* query - builds a new query obect for use against eachWhere

