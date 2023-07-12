___INFO___

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

/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
const Firestore = require("Firestore");
const Promise = require("Promise");
const getEventData = require("getEventData");
const logToConsole = require("logToConsole");
const makeNumber = require("makeNumber");

/**
 * Sums up all value data in items.
 */
function sumValues(values) {
  let total = 0;
  for (const value of values) {
    if (value) {
      total += value;
    } else {
      logToConsole("Value is 0, undefined or null");
    }
  }
  return total;
}

/**
 * Fetches all item values in the event data.
 */
function getItemValues(items) {
  const valueRequests = [];
  for (const item of items) {
    valueRequests.push(getFirestoreValue(item));
  }
  return Promise.all(valueRequests);
}

/**
 * Get the value & return rate from Firestore & calculate conversion value.
 */
function getFirestoreValue(item) {
  if (!item.item_id) {
    logToConsole("No item ID in item");
    return data.zeroIfNotFound ? 0 : item.price;
  }

  return Promise.create((resolve) => {
    let value = data.zeroIfNotFound ? 0 : item.price;
    const path = data.collectionId + "/" + item.item_id;
    return Firestore.read(path, { projectId: data.gcpProjectId })
    .then((result) => {
      if (result.data.hasOwnProperty(data.valueField) &&
          result.data.hasOwnProperty(data.returnRateField)) {
        const quantity = item.hasOwnProperty("quantity") ? item.quantity : 1;
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


