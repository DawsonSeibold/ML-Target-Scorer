//
//  CSVParser.swift
//  target scorer
//
//  Created by Dawson Seibold on 8/4/18.
//  Copyright © 2018 Smile App Development. All rights reserved.
//

import Foundation

class CSVParser: NSObject {
    
    var CSVText = ""
    var rowsText: [String] = []
    var rows: [[String]] = []
    var columnTitles: [String] = []

    //Target Scoreer Specific
    var usedImageNumbers: [Int] = []
    var highestImageNumber: Int = -1
    
    
    func parseCSV(text: String) {
        CSVText = text
        rowsText = text.components(separatedBy: "\n")
        
        rows = rowsText.map({ (row) -> Array<String> in
            return row.components(separatedBy: ",")
        })
        columnTitles = rows.removeFirst()
        
        print("Column Titles: ", columnTitles)
        print("CSV Array: ", rows)
        getUsedImageNumbers()
        print("Used Image Name Numbers: ", usedImageNumbers)
    }
    
    func getValueAt(row: Int, column: Int) -> String? {
        if (rows.count - 1 >= row) {
            if (rows[row].count - 1 >= column) {
                return rows[row][column]
            }
        }
        return nil
    }
    
    private func getUsedImageNumbers() {
        usedImageNumbers.removeAll()
        for row in rows {
            let imageName = row[0]
            let imageNumber = Int(imageName.uppercased().replacingOccurrences(of: "/IMG_", with: "").replacingOccurrences(of: ".JPG", with: ""))
            guard let number = imageNumber else { continue }
            usedImageNumbers.append(number)
        }
        findTheHighestNumberUsed()
    }
    
    func findTheHighestNumberUsed() {
        var highestNumber = -1
        for number in usedImageNumbers {
            if number > highestNumber { highestNumber = number }
        }
        highestImageNumber = highestNumber
        print("Highest Image Number: ", highestImageNumber)
    }
    
    ///Add a row to the bottom of the csv file and array
    func addRow(_ row: [String]) {
        rows.append(row)
        var newRow = ""
        for (index,column) in row.enumerated() {
            newRow += column
            if (index < row.count - 1) {//Not Last column
                newRow += ","
            }
        }
        newRow += "\n"
        CSVText += newRow
        
        getUsedImageNumbers()
    }
    ///Add a row to the bottom of the csv file and array
    func addRow(imagePath: String, score: String, position: String, totalScore: String, week: String) {
        var list: [String] = []
        list.append(imagePath)
        list.append(score)
        list.append(position)
        list.append(totalScore)
        list.append(week)
        
        addRow(list)
    }
    
    
}
