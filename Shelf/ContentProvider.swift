//
//  ContentProvider.swift
//  Shelf
//
//  Created by Anastasy on 8/28/23.
//  Copyright © 2023 Moonlight Game Streaming Project. All rights reserved.
//

import TVServices
import UIKit

class MyTopShelfContent: NSObject, TVTopShelfContent, NSSecureCoding {
  static var supportsSecureCoding: Bool {
    return true
  }

  var items: [TVTopShelfItem] = []

  override init() {
    super.init()
  }

  required init?(coder: NSCoder) {
    super.init()
    self.items = coder.decodeObject(forKey: "items") as? [TVTopShelfItem] ?? []
  }

  func encode(with coder: NSCoder) {
    coder.encode(self.items, forKey: "items")
  }
}

func urlForImage(named name: String) -> URL? {

  if let fileURL = Bundle.main.url(forResource: name, withExtension: "png") {
    return fileURL
  }

  return nil

}

func urlForCachedImage(uuid: String, appId: String) -> URL? {
    let appGroupIdentifier = "group.MoonlightTV"
       let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)

    var cachesURL = url!.appendingPathComponent("Library", isDirectory: true).appendingPathComponent("Caches", isDirectory: true)
    let imageName = "\(uuid)-\(appId)"
    cachesURL = cachesURL.appendingPathComponent(imageName).appendingPathExtension("png")
    

    if FileManager.default.fileExists(atPath: cachesURL.path) {
        return cachesURL
    }
    
    return nil
}

class ContentProvider: TVTopShelfContentProvider {

  override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {

    var hostSections: [String: [TVTopShelfSectionedItem]] = [:]

    if let sharedDefaults = UserDefaults(suiteName: "group.MoonlightTV"),
      let jsonString = sharedDefaults.string(forKey: "appList"),
      let jsonData = jsonString.data(using: .utf8)
    {
      do {
        if let appList = try JSONSerialization.jsonObject(with: jsonData, options: [])
          as? [[String: Any]]
        {
          for appDict in appList {
            if let appId = appDict["id"] as? String,
              let hostName = appDict["hostName"] as? String,
              let hostUUID = appDict["hostUUID"] as? String
            {
              let item = TVTopShelfSectionedItem(identifier: appId)
              item.title = appDict["name"] as? String

                item.setImageURL(urlForImage(named: "NoAppImage"), for: [.screenScale1x, .screenScale2x])
            if let cachedImageURL = urlForCachedImage(uuid: hostUUID, appId: appId) {
                      item.setImageURL(cachedImageURL, for: [.screenScale1x, .screenScale2x])
                    } else {
                      item.setImageURL(urlForImage(named: "NoAppImage"), for: [.screenScale1x, .screenScale2x])
                    }
                
              if hostSections[hostName] == nil {
                hostSections[hostName] = []
              }

              hostSections[hostName]?.append(item)

              let action = TVTopShelfAction(
                url: URL(
                  string: "moonlight://appClicked?app=\(appId)&UUID=\(hostUUID)")!)
              item.playAction = action
              item.displayAction = action
            }
          }
        }
      } catch {
        print("appList deserialization failed: \(error)")
      }
    }

    var sectionedItemCollections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []

    for (hostName, items) in hostSections {
      let itemCollection = TVTopShelfItemCollection<TVTopShelfSectionedItem>(items: items)
      itemCollection.title = "Moonlight: \(hostName)"
      sectionedItemCollections.append(itemCollection)
    }

    let sectionedContent = TVTopShelfSectionedContent(sections: sectionedItemCollections)

    completionHandler(sectionedContent)
  }
}
