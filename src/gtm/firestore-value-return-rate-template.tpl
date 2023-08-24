﻿___INFO___

{
  "type": "MACRO",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Item Value with Returns (Firestore)",
  "description": "Variable that retrieves values from Firestore for each item_id in the items array of the event data.\n\nFor more information head over to: https://github.com/google/gps_soteria",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "gcpProjectId",
    "displayName": "GCP Project ID (Where Firestore is located)",
    "simpleValueType": true,
    "notSetText": "projectId is retrieved from the environment variable GOOGLE_CLOUD_PROJECT",
    "help": "Google Cloud Project ID where the Firestore database with margin data is located, leave empty to read from GOOGLE_CLOUD_PROJECT environment variable",
    "canBeEmptyString": true
  },
  {
    "type": "TEXT",
    "name": "valueField",
    "displayName": "Value Field",
    "simpleValueType": true,
    "defaultValue": "value",
    "help": "Field in the Firestore Document that holds the value data for the item",
    "notSetText": "Please set the Firestore document field for value data"
  },
  {
    "type": "TEXT",
    "name": "returnRateField",
    "displayName": "Return Rate Field",
    "simpleValueType": true,
    "help": "Field in the Firestore Document that holds the return rate data for the item",
    "defaultValue": "return_rate",
    "notSetText": "Please set the Firestore document field for return rate data"
  },
  {
    "type": "TEXT",
    "name": "collectionId",
    "displayName": "Firestore Collection ID",
    "simpleValueType": true,
    "defaultValue": "products",
    "help": "The collection in Firestore that contains the products"
  },
  {
    "type": "CHECKBOX",
    "name": "zeroIfNotFound",
    "checkboxText": "Zero if not found",
    "simpleValueType": true,
    "defaultValue": true,
    "help": "If true items that cannot be found in Firestore will be 0. If false items that cannot be found in Firestore will have their original value from the event data.",
    "alwaysInSummary": true
  }
]


___SANDBOXED_JS_FOR_SERVER___

// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

/**
 * @fileoverview sGTM variable tag that uses data from Firestore to calculate a
 * new conversion value based on items in the datalayer.
 * @see {@link https://developers.google.com/analytics/devguides/collection/ga4/reference/events?client_type=gtag#purchase_item}
 * @version 1.0.1
 */

const Firestore = require("Firestore");
const Promise = require("Promise");
const getEventData = require("getEventData");
const logToConsole = require("logToConsole");
const makeNumber = require("makeNumber");
const makeString = require("makeString");
const getType = require('getType');


/**
 * Sum the numbers provided in the values array.
 * @param {!Array<number>} values - the values to sum
 * @returns {string} the total cast to a string. As a numeric zero can cause
 * unexpected behaviour in sGTM.
 */
function sumValues(values) {
  let total = 0;
  for (const value of values) {
    if (getType(value) === 'number') {
      total += value;
    } else {
      logToConsole("Value is not a number");
    }
  }
  // Cast to string as a numeric zero causes sGTM to default to revenue value
  return makeString(total);
}

/**
 * Fetch all item values in the event data.
 * @param {!Array<!Object>} items - an array of items from the datalayer that
 * follow this schema:
 * https://developers.google.com/analytics/devguides/collection/ga4/reference/events?client_type=gtag#purchase_item
 * @returns {!Promise<!Array<number>>} An array of numbers where each number is
 * the new value for each item.
 */
function getItemValues(items) {
  const valueRequests = [];
  for (const item of items) {
    valueRequests.push(getFirestoreValue(item));
  }
  return Promise.all(valueRequests);
}

/**
 * Get the default value for the item.
 * @param {!Object} item - an item from the datalayer that is expected to follow
 * this schema:
 * https://developers.google.com/analytics/devguides/collection/ga4/reference/events?client_type=gtag#purchase_item
 * @returns {number} will return 0 if zeroIfNotFound is True in the variable
 * config, otherwise it will return the revenue value.
 */
function getDefaultValue(item) {
  const itemPrice = data.zeroIfNotFound ? 0 : item.price;
  const quantity = item.hasOwnProperty("quantity") ? item.quantity : 1;
  return makeNumber(itemPrice) * makeNumber(quantity);
}

/**
 * Use Firestore to determine what the new value should be for this item.
 * @param {!Object} item - an item from the datalayer that is expected to follow
 * this schema:
 * https://developers.google.com/analytics/devguides/collection/ga4/reference/events?client_type=gtag#purchase_item
 * @returns {number} the new value for this item based on information in the
 * Firestore document. If the item cannot be found in Firestore, it falls back
 * to the default value @see {@link getDefaultValue}.
 */
function getFirestoreValue(item) {
  let value = getDefaultValue(item);

  if (!item.item_id) {
    logToConsole("No item ID in item");
    return value;
  }

  const path = data.collectionId + "/" + item.item_id;

  return Promise.create((resolve) => {
    return Firestore.read(path, { projectId: data.gcpProjectId })
    .then((result) => {
      if (result.data.hasOwnProperty(data.valueField) &&
          result.data.hasOwnProperty(data.returnRateField)) {
        const quantity = makeNumber(
          item.hasOwnProperty("quantity") ? item.quantity : 1);
        const documentValue = makeNumber(result.data[data.valueField]);
        const returnRate = makeNumber(result.data[data.returnRateField]);
        value = (1 - returnRate) * documentValue * quantity;
        logToConsole(
          "quantity: " +
          quantity +
          " documentValue: " +
          documentValue +
          " returnRate: " +
          returnRate +
          " value: " +
          value);
      } else {
        logToConsole(
          "Firestore document " +
            item.item_id +
            " doesn't have a value field " +
            data.valueField +
            " or return rate field " +
            data.returnRateField
        );
      }
    })
    .catch((error) => {
      logToConsole("Error retrieving Firestore document `" + path + "`", error);
    })
    .finally(() => {
      resolve(value);
    });
  });
}

// Entry point
const items = getEventData("items");
logToConsole('items', items);
return getItemValues(items)
  .then(sumValues)
  .catch((error) => {
    logToConsole("Error", error);
  });


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "all"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_firestore",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedOptions",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "projectId"
                  },
                  {
                    "type": 1,
                    "string": "path"
                  },
                  {
                    "type": 1,
                    "string": "operation"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "GOOGLE_CLOUD_PROJECT"
                  },
                  {
                    "type": 1,
                    "string": "products/*"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_event_data",
        "versionId": "1"
      },
      "param": [
        {
          "key": "eventDataAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios: []


___NOTES___

Created on 8/3/2022, 3:02:04 PM

