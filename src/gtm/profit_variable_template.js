// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/**
 * Return the profit value from Firestore for purchased items in ecomm event.
 *
 * This variable template fetches the profit document from Firestore, retrieves
 * the purchased items from the ecommerce purchase event, and calculates the
 * profit of these items. This value is returned.
 */
const Firestore = require('Firestore');
const getEventData = require('getEventData');
const logToConsole = require('logToConsole');
const makeNumber = require('makeNumber');

// Set this to the document containing the profit data
const documentPath = 'profit/products';

// The name of the project containing the Firestore data.
const gcpProjectId = 'project-name-here';

/**
 * Sum the profit for the purchased items.
 * @param {!Object} profitData A map containing the profit data.
 * @return {undefined}
 */
function processProfitData(profitData) {
  let totalProfit = 0;
  const purchasedItems = getEventData('items');
  for (const purchasedItem of purchasedItems) {
    logToConsole('Processing item: ' + purchasedItem.item_id);
    if (profitData.hasOwnProperty(purchasedItem.item_id)) {
      const profit = makeNumber(profitData[purchasedItem.item_id].profit);
      logToConsole('Profit is: ' + profit);
      totalProfit += profit;
    } else {
      logToConsole('Item not found in the profit data.');
      data.gtmOnFailure();
      return;
    }
  }
  logToConsole('The total profit is: ');
  logToConsole(totalProfit);
  return totalProfit;
}

return Firestore.read(documentPath, { projectId: gcpProjectId })
      .then((result) => {
        logToConsole('Profit data:');
        logToConsole(result.data);
        return result.data;
      })
      .then((profitData) => {
        return processProfitData(profitData);
      });
