'use strict'

describe "$indexedDB", ->
  providerConfig = {}
  $q = {}

  beforeEach ->
    angular.module('indexedDB').config ($indexedDBProvider) ->
      providerConfig = $indexedDBProvider

    module 'indexedDB'
    inject(->)

  itPromises = (message, testFunc) ->
    it message, (done) ->
      testFunc.apply(this, []).finally(done)

  promiseBefore = (beforeFunc) ->
    beforeEach (done) ->
      beforeFunc.apply(this, []).finally(done)

  beforeEach inject ($indexedDB, _$q_) ->
    @subject = $indexedDB
    $q = _$q_

  beforeEach ->
    providerConfig.connection("testDB")
    .upgradeDatabase 1, (event, db, txn) ->
      db.createObjectStore "TestObjects", keyPath: 'id'
    .upgradeDatabase 2, (event, db, txn) ->
      store = db.createObjectStore "ComplexTestObjects", keyPath: 'id'
      store.createIndex "name", "name", unique: false

  afterEach (done) ->
    @subject.deleteDatabase().finally(done)

  describe "#openStores", ->

    itPromises "returns the object stores", ->
      @subject.openStores ["TestObjects","ComplexTestObjects"] , (store1, store2) ->
        store1.insert({id: 1, data : "foo"})
        store2.insert({id: 2, name: "barf"})
        store1.getAllKeys().then (keys) ->
          expect(keys.length).toEqual(1)
      .catch (err)->
        # not run to here
        expect(err).toBeUndefined()

  describe "#openAllStores", ->
      itPromises "returns all the object stores", ->
        @subject.openAllStores (stores...) ->
          expect(stores.length).toEqual(2)
          stores[0].insert({id: 1, data : "foo"})
          stores[1].insert({id: 2, name: "barf"})
          stores[0].getAllKeys().then (keys) ->
            expect(keys.length).toEqual(1)

  describe '#flush', ->
    itPromises "it flushes any waiting transactions", ->
      @subject.openStore "TestObjects", (store) =>
        for i in [0 .. 10000]
          store.insert([
            {id: i, data: "foo", extra: "a" * i}
          ])
        @subject.flush()

  describe '#openStore', ->

    itPromises "returns the object store", ->
      @subject.openStore "TestObjects", (store) ->
        store.getAllKeys().then (keys) ->
          expect(keys.length).toEqual(0)

    itPromises "throws an error for non-existent stores", ->
      @subject.openStore("NoSuchStore", (->)).catch (problem) ->
        expect(problem).toEqual("Object stores NoSuchStore do not exist.")

    describe "multiple transactions", ->
      promiseBefore ->
        @subject.openStore "TestObjects", (store) ->
          store.insert([
            {id: 1, data: "foo"},
            {id: 2, data: "bar"}
          ])

      itPromises "can open a transaction within a transaction", ->
        @subject.openStore "TestObjects", (store) =>
          p = store.insert
          @subject.openStore "TestObjects", (store2) ->
            expect( store2 ).toBeTruthy()

    describe "#delete", ->
      promiseBefore ->
        @subject.openStore "TestObjects", (store) ->
          store.insert([
            {id: 1, data: "foo"},
            {id: 2, data: "bar"}
          ])

      itPromises "can delete an item", ->
        @subject.openStore "TestObjects", (store) ->
          store.delete(1)
          store.getAll().then (objects) ->
            expect(objects.length).toEqual(1)
            expect(objects[0].id).toEqual(2)

      itPromises "errors gracefully when it doesn't exist", ->
        @subject.openStore "TestObjects", (store) ->
          store.delete(55)
        .catch ->
          expect(true).toBeFalsy()

    describe "#query", ->
      promiseBefore ->
        @subject.openStore "ComplexTestObjects", (store) ->
          store.insert([
              {id: 1, data: "foo", name: "bbb"},
              {id: 2, data: "bar", name: "aaa"},
              {id: 3, data: "woof", name: "zzz"}
            ]
          )

      itPromises "iterates by the index name with lt and lte", ->
        @subject.openStore "ComplexTestObjects", (store) ->
          store.findWhere(store.query().$index("name")).then (results) ->
            expect( results[0].id ).toEqual(2)
          store.findWhere(store.query().$index("name").$lt("bbb")).then (results) ->
            expect( results.length).toEqual(1)
            expect( results[0].id).toEqual(2)
          store.findWhere(store.query().$index("name").$lte("bbb")).then (results) ->
            expect( results.length).toEqual(2)
            expect( results[0].id).toEqual(2)
            expect( results[1].id).toEqual(1)

      itPromises "iterates by the index name with gt and gte", ->
        @subject.openStore "ComplexTestObjects", (store) ->
          store.findWhere(store.query().$index("name")).then (results) ->
            expect( results[0].id ).toEqual(2)
          store.findWhere(store.query().$index("name").$gt("bbb")).then (results) ->
            expect( results.length).toEqual(1)
            expect( results[0].id).toEqual(3)
          store.findWhere(store.query().$index("name").$gte("bbb")).then (results) ->
            expect( results.length).toEqual(2)
            expect( results[1].id).toEqual(3)
            expect( results[0].id).toEqual(1)

      itPromises "finds one object with $eq", ->
        @subject.openStore "ComplexTestObjects", (store) ->
          store.findWhere(store.query().$index("name").$eq("bbb")).then (results) ->
            expect( results[0].id ).toEqual(1)
            expect( results.length).toEqual(1)

      itPromises "finds two objects with $between", ->
        @subject.openStore "ComplexTestObjects", (store) ->
          store.findWhere(store.query().$index("name").$between("aaa","bbb")).then (results) ->
            expect( results[0].id ).toEqual(2)
            expect( results.length).toEqual(2)

      itPromises "orders differently with $desc", ->
        @subject.openStore "ComplexTestObjects", (store) ->
          store.findWhere(store.query().$index("name").$desc()).then (results) ->
            expect( results[0].id ).toEqual(3)
            expect( results.length).toEqual(3)

    describe "#find", ->
      promiseBefore ->
        @subject.openStore "TestObjects", (store) ->
          store.insert([
            {id: 1, data: "foo"},
            {id: 2, data: "bar"}
          ])

      itPromises "finds an existing item", ->
        @subject.openStore "TestObjects", (store) ->
          store.find(1).then (item) ->
            expect(item.data).toEqual("foo")

      itPromises "returns the result of the callback to the receiver", ->
        @subject.openStore "TestObjects", (store) ->
          store.find(1)
        .then (item) ->
          expect(item.data).toEqual("foo")
          true

      itPromises "does not find a non-existent item", ->
        @subject.openStore "TestObjects", (store) ->
          store.find(404).then (item) ->
            expect(false).toBeTruthy()
          .catch (error) ->
            expect(true).toBeTruthy()

    describe "#each", ->
      promiseBefore ->
        @subject.openStore "TestObjects", (store) ->
          store.insert([
            {id: 1, data: "foo", name: "bbb"},
            {id: 2, data: "bar", name: "aaa"}
          ])
        @subject.openStore "ComplexTestObjects", (store) ->
          store.insert([
              {id: 1, data: "foo", name: "bbb"},
              {id: 2, data: "bar", name: "aaa"}
            ]
          )

      itPromises " yields the items in succession", ->
        @subject.openStore "TestObjects", (store) ->
          i = 1
          store.each().then null,null, (item) ->
            expect(item.id).toEqual(i)
            i += 1

      itPromises " yields the items in opposite succession given a different direction", ->
        @subject.openStore "TestObjects", (store) =>
          i = 2
          store.each(direction: @subject.queryDirection.descending).then null,null, (item) ->
            expect(item.id).toEqual(i)
            i -= 1

      itPromises " uses a range on the object keys", ->
        @subject.openStore "TestObjects", (store) =>
          i = 1
          store.each(beginKey: 1, endKey: 1).then null,null, (item) ->
            expect(item.id).toEqual(i)
            i += 1
          .then (items) ->
            expect(items.length).toEqual(1)

      itPromises " can operate on an index", ->
        @subject.openStore "ComplexTestObjects", (store) ->
          i = 2
          store.eachBy("name").then null,null, (item) ->
            expect(item.id).toEqual(i)
            i -= 1

    describe "#upsert", ->
      itPromises "adds the item", ->
        @subject.openStore "TestObjects", (store) ->
          store.upsert({id: 1, data: "something"}).then (result) ->
            expect(result).toBeTruthy()
          store.getAll().then (objects) ->
            expect(objects.length).toEqual(1)
            expect(objects[0].data).toEqual("something")
          store.find(1).then (object) ->
            expect(object.id).toEqual(1)

      itPromises "can add an item of the same key twice", ->
        @subject.openStore "TestObjects", (store) ->
          store.upsert({id: 1, data: "something"})
          store.upsert({id: 1, data: "somethingelse"}).catch (errorMessage) ->
            expect(true).toBeFalsy()
          .then ->
            expect(true).toBeTruthy()

      itPromises "can add multiple items", ->
        @subject.openStore "TestObjects", (store) ->
          store.upsert([
            {id: 1, data: "1"},
            {id: 2, data: "2"}
          ]).then (result) ->
            expect(result).toBeTruthy()
          store.getAll().then (objects) ->
            expect(objects.length).toEqual(2)
          store.count().then (count) ->
            expect(count).toEqual(2)

    describe "#insert", ->
      itPromises "adds the item", ->
        @subject.openStore "TestObjects", (store) ->
          store.insert({id: 1, data: "something"}).then (result) ->
            expect(result).toBeTruthy()
          store.getAll().then (objects) ->
            expect(objects.length).toEqual(1)
            expect(objects[0].data).toEqual("something")
          store.find(1).then (object) ->
            expect(object.id).toEqual(1)

      itPromises "cannot add an item of the same key twice", ->
        @subject.openStore "TestObjects", (store) ->
          store.insert({id: 1, data: "something"})
          store.insert({id: 1, data: "somethingelse"}).catch (errorMessage) ->
            expect(errorMessage).toEqual("Key already exists in the object store.")
            return $q.reject("expected")
          .then ->
            expect(false).toBeTruthy()

      itPromises "can add multiple items", ->
        @subject.openStore "TestObjects", (store) ->
          store.insert([
            {id: 1, data: "1"},
            {id: 2, data: "2"}
          ]).then (result) ->
            expect(result).toBeTruthy()
          store.getAll().then (objects) ->
            expect(objects.length).toEqual(2)
          store.count().then (count) ->
            expect(count).toEqual(2)

      itPromises "does nothing for no items", ->
        @subject.openStore "TestObjects", (store) ->
          store.insert([]).then ->
            expect(true).toBeTruthy()




