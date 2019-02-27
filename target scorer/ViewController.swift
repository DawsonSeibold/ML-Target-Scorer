//
//  ViewController.swift
//  target scorer
//
//  Created by Dawson Seibold on 4/1/18.
//  Copyright © 2018 Smile App Development. All rights reserved.
//

import UIKit
import AVKit
import Vision
import Photos


class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {

    var captureSession = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    let cameraQueue = DispatchQueue(label: "cameraQueue", attributes: [], target: nil)
    
    let CSVparser = CSVParser()
    
    var setupResult: SessionSetupResult = .success
    enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    var week: Int = 0
    var position: positions = .prone
    var total_score: Int = 0
    var score: Int = 0
    var image_path: String = ""
    var image: UIImage?
    
    enum positions {
        case prone
        case offhand
        case kneeling
    }
    
    
    var model: VNCoreMLModel?
    var outputLable: UILabel?
    var percentageLable: UILabel?
    var percentageBar: UIPercentageBar?
    var labelView: UIView?
    var photoButton: UIView?
    var newTargetButton: UIButton?
    var currentTargetInfo: UITextView?
    var changeImageNameNumberButton: UIButton?
    var takenImageView = UIImageView()
    var takenImageBorder = UIView()
    var saveTargetButton: UIButton?
    var deleteTakenImageButton: UIButton?
    var shareButton: UIButton?
    
    let fileName = "Target-Data.csv"
    var path: URL?
    var fileURL: URL?
    var csvText = "short_path,score,position,page_score,week"
    var writeFile: Bool = true
    var lastImageNumber = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("\(OpenCVWrapper.openCVVersionString())")
        
        //Read the current csv file
        path = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        fileURL = path?.appendingPathComponent(fileName)
        
        do {
            csvText = try String(contentsOf: fileURL!, encoding: .utf8)
        }catch {
            print("Error Reading File")
            writeFile = false
        }
        
        CSVparser.parseCSV(text: csvText)
        lastImageNumber = CSVparser.highestImageNumber

        checkAuthorization()
        
        cameraQueue.async { [unowned self] in
            self.configureSession()
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return}

        let request = VNCoreMLRequest(model: model!) { (finishReq, err) in
            guard let results = finishReq.results as? [VNClassificationObservation] else {return}
            guard let firstObservation = results.first else {return}
            print(firstObservation.identifier, firstObservation.confidence)

            DispatchQueue.main.async {

                self.outputLable?.text = "Score: \(firstObservation.identifier)"

                let percent = Int(firstObservation.confidence * 100)
                self.percentageLable?.text = "\(percent)%"
                self.percentageBar?.updatePercentage(firstObservation.confidence)
            }
        }

        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
    
    @objc func takePhoto() {
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.flashMode = .auto
        
        guard let firstAvailablePreview = photoSettings.availablePreviewPhotoPixelFormatTypes.first else {return}
        photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: firstAvailablePreview]
        
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    //    MARK: Camera Functions
    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: //All Good
            break
        case .notDetermined: //User Not prompted to accept yet.
            cameraQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { (granted) in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.cameraQueue.resume()
            }
        default: //Denied access
            setupResult = .notAuthorized
        }
    }
    
    func configureSession() {
        if setupResult != .success {return}
        
        //Camera
        captureSession = AVCaptureSession()
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {return}
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else {return}
        
        captureSession.addInput(input)
//        captureSession.sessionPreset = .photo
        captureSession.sessionPreset = .hd1920x1080
        captureSession.startRunning()
        
        DispatchQueue.main.async {
            let previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            self.view.layer.addSublayer(previewLayer)
            previewLayer.frame = self.view.frame
            
            self.setupUI()
        }
        
        model = try? VNCoreMLModel(for: targetScoring().model)
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
        
        captureSession.addOutput(photoOutput)
        photoOutput.isHighResolutionCaptureEnabled = true
        photoOutput.isLivePhotoCaptureEnabled = false
    }
    
    func setupUI() {
        labelView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 80))
        labelView?.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(labelView!)
        
        let blurEffect = UIBlurEffect(style: .dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = (labelView?.frame)!
        labelView?.addSubview(blurEffectView)
        NSLayoutConstraint.activate([
            (labelView?.topAnchor.constraint(equalTo: self.view.topAnchor))!,
            (labelView?.leadingAnchor.constraint(equalTo: self.view.leadingAnchor))!,
            (labelView?.trailingAnchor.constraint(equalTo: self.view.trailingAnchor))!,
            (labelView?.heightAnchor.constraint(equalToConstant: 60))!
        ])
        
        outputLable = UILabel(frame: CGRect(x: 10, y: 20, width: (view.frame.width / 2) - 20 , height: 60))
        outputLable?.textAlignment = .left
        outputLable?.text = "Score: Unknown"
        outputLable?.font = UIFont.systemFont(ofSize: 40, weight: .heavy)
        outputLable?.textColor = .white
        labelView?.addSubview(outputLable!)
        
        percentageLable = UILabel(frame: CGRect(x: (view.frame.width / 2) + 10 , y: 20, width: (view.frame.width / 2) - 20, height: 60))
        percentageLable?.textAlignment = .right
        percentageLable?.text = "100%";
        percentageLable?.font = UIFont.systemFont(ofSize: 45, weight: .heavy)
        percentageLable?.textColor = .white
        labelView?.addSubview(percentageLable!)
        
        percentageBar = UIPercentageBar(frame: CGRect(x: 0, y: 80, width: view.frame.width, height: 200))
        percentageBar?.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(percentageBar!)
//        NSLayoutConstraint.activate([
//            (percentageBar?.topAnchor.constraint(equalTo: (labelView?.bottomAnchor)!))!
//        ])
        
//        photoButton = UIView(frame: CGRect(x: view.frame.width / 2 - 37.5, y: view.frame.height - 85, width: 75, height: 75))
//        photoButton?.backgroundColor = .white
//        photoButton?.layer.borderColor = UIColor.black.cgColor
//        photoButton?.alpha = 0.4
//        photoButton?.layer.cornerRadius = (self.photoButton?.frame.width)! / 2
//        photoButton?.isUserInteractionEnabled = false
//        view.addSubview(self.photoButton!)
        
//        let tap = UITapGestureRecognizer(target: self, action: #selector(ViewController.takePhoto))
//        photoButton!.addGestureRecognizer(tap)

//        newTargetButton = UIButton(type: .system)
//        newTargetButton?.frame = CGRect(x: 10, y: 20, width: 150, height: 45)
//        newTargetButton?.backgroundColor = .white
//        newTargetButton?.alpha = 0.8
//        newTargetButton?.layer.cornerRadius = 8
//        newTargetButton?.setTitle("Start New Target", for: .normal)
//        newTargetButton?.addTarget(self, action: #selector(ViewController.startNewTarget), for: .touchUpInside)
//        view.addSubview(newTargetButton!)
        
//        currentTargetInfo = UITextView(frame: CGRect(x: 10, y: 65, width: 250, height: 300))
//        currentTargetInfo?.backgroundColor = .clear
//        currentTargetInfo?.textColor = UIColor.green
//        currentTargetInfo?.isUserInteractionEnabled = false
//        updateCurrentTargetInfoUI()
//        view.addSubview(currentTargetInfo!)
        
//        changeImageNameNumberButton = UIButton(type: .system)
//        changeImageNameNumberButton?.frame = CGRect(x: view.frame.maxX - 160, y: 20, width: 150, height: 45)
//        changeImageNameNumberButton?.backgroundColor = .white
//        changeImageNameNumberButton?.alpha = 0.8
//        changeImageNameNumberButton?.layer.cornerRadius = 8
//        changeImageNameNumberButton?.setTitle("Starting IMG Number", for: .normal)
//        changeImageNameNumberButton?.addTarget(self, action: #selector(ViewController.getStartingImageNumber), for: .touchUpInside)
//        view.addSubview(changeImageNameNumberButton!)
        
//        takenImageView.frame = CGRect(x: 20, y: 20, width: view.frame.width - 40, height: view.frame.height - 40)
//        takenImageView.layer.cornerRadius = 10
//        takenImageView.layer.masksToBounds = true
//        takenImageView.backgroundColor = .white
        
//        takenImageBorder.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
//        takenImageBorder.backgroundColor = .white
//        takenImageBorder.alpha = 0.6
//        let blurEffect = UIBlurEffect(style: .dark)
//        let blurEffectView = UIVisualEffectView(effect: blurEffect)
//        blurEffectView.frame = self.view.bounds
//        takenImageBorder.addSubview(blurEffectView)
        
//        saveTargetButton = UIButton(type: .system)
//        saveTargetButton?.frame = CGRect(x: 25, y: 25, width: 100, height: 45)
//        saveTargetButton?.backgroundColor = .black
//        saveTargetButton?.alpha = 0.6
//        saveTargetButton?.tintColor = .white
//        saveTargetButton?.layer.cornerRadius = 8
//        saveTargetButton?.setTitle("Save Target", for: .normal)
//        saveTargetButton?.addTarget(self, action: #selector(ViewController.saveImage), for: .touchUpInside)
//        saveTargetButton?.isHidden = true
//        view.addSubview(saveTargetButton!)
        
//        deleteTakenImageButton = UIButton(type: .system)
//        deleteTakenImageButton?.frame = CGRect(x: view.frame.maxX - 70, y: 25, width: 45, height: 45)
//        deleteTakenImageButton?.backgroundColor = .black
//        deleteTakenImageButton?.alpha = 0.6
//        deleteTakenImageButton?.tintColor = .white
//        deleteTakenImageButton?.layer.cornerRadius = 8
//        let closeText = NSAttributedString(string: "X", attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 28.0)])
//        deleteTakenImageButton?.setAttributedTitle(closeText, for: .normal)
//        deleteTakenImageButton?.addTarget(self, action: #selector(ViewController.deleteTakenPhoto), for: .touchUpInside)
//        deleteTakenImageButton?.isHidden = true
//        view.addSubview(deleteTakenImageButton!)
        
//        shareButton = UIButton(type: .system)
//        shareButton?.frame = CGRect(x: view.frame.maxX - 90, y: 75, width: 80, height: 45)
//        shareButton?.backgroundColor = .white
//        shareButton?.alpha = 0.8
//        shareButton?.layer.cornerRadius = 8
//        shareButton?.setTitle("Share", for: .normal)
//        shareButton?.addTarget(self, action: #selector(ViewController.shareFiles), for: .touchUpInside)
//        view.addSubview(shareButton!)
    }
    
    func clearTakenPhotoUI() {
        DispatchQueue.main.async {
            self.takenImageView.removeFromSuperview()
            self.takenImageBorder.removeFromSuperview()
            self.saveTargetButton?.isHidden = true
            self.deleteTakenImageButton?.isHidden = true
            
            self.photoButton?.isUserInteractionEnabled = true
        }
        enableTakePhotoUI()
    }
    
    func enableTakePhotoUI() {
        DispatchQueue.main.async {
            self.newTargetButton?.isHidden = false
            self.currentTargetInfo?.isHidden = false
            self.photoButton?.isHidden = false
            self.photoButton?.isUserInteractionEnabled = true
        }
    }
    
    func disableTakePhotoUI() {
        DispatchQueue.main.async {
            self.newTargetButton?.isHidden = true
            self.currentTargetInfo?.isHidden = true
            self.photoButton?.isHidden = true
        }
    }
    
    func updateCurrentTargetInfoUI() {
        let allEmpty =  (week == 0 && position == .prone && total_score == 0)
        if !allEmpty {
            currentTargetInfo?.text = "Week: \(week)\nPosition: \(position)\nTotal Score: \(total_score)\nNext Image Name: \(getImageName())"
        }else {
            currentTargetInfo?.text = "No Target Started...\nNext Image Name: \(getImageName())"
        }
//        currentTargetInfo?.isHidden = (allEmpty ? true : false)
    }
    
    func getImageName() -> String {
        if CSVparser.usedImageNumbers.contains(lastImageNumber + 1) {
            var newCount = lastImageNumber + 2
            while (CSVparser.usedImageNumbers.contains(newCount)) {
                newCount += 1
            }
            
            lastImageNumber = newCount - 1
            let imageName = "IMG_\(newCount).jpg"
            return imageName
        }else {
            let imageName = "IMG_\(lastImageNumber + 1).jpg"
            return imageName
        }
    }
    
    ///Askes the user what number the image names should start with
    @objc func getStartingImageNumber() {
        let alert = UIAlertController(title: "Change Starting Image Name Number", message: "Choose a number to start the images names with.", preferredStyle: .alert)
        alert.addTextField { (textField:UITextField) in
            textField.placeholder = "Starting Number"
            textField.keyboardType = .numberPad
        }
        alert.addAction(UIAlertAction(title: "Change", style: .default, handler: { (action:UIAlertAction) in
            if let textField = alert.textFields?.first {
                if textField.hasText { self.lastImageNumber = Int(textField.text!)! - 1 }
                self.updateCurrentTargetInfoUI()
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc func shareFiles() {
        var datasetDirectory = path?.appendingPathComponent("dataset")
        
        let vc = UIActivityViewController(activityItems: [datasetDirectory, fileURL], applicationActivities: [])
        
        self.present(vc, animated: true)
        
    }
    
    @objc func startNewTarget() {
        print("Start New Target")
        let alert = UIAlertController(title: "Start New Target", message: "Please fill in the following information", preferredStyle: .alert)
        alert.addTextField { (textField:UITextField) in
            textField.placeholder = "Week"
            textField.keyboardType = .numberPad
            textField.tag = 50
        }
        alert.addTextField { (textField:UITextField) in
            textField.placeholder = "Total Score"
            textField.keyboardType = .numberPad
            textField.tag = 51
        }
        
        alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: { (action:UIAlertAction) in
            alert.textFields?.forEach({ (textField: UITextField) in
                if textField.tag == 50 { //Week
                    if textField.hasText { self.week = Int(textField.text!)! }
                }else { //Total Score
                    if textField.hasText { self.total_score = Int(textField.text!)! }
                }
            })
            
            //Show a new alert for the positon
            let positonAlert = UIAlertController(title: "Target Postion", message: "Please choose the position for the target.", preferredStyle: .actionSheet)
            positonAlert.addAction(UIAlertAction(title: "Prone", style: .default, handler: { (action:UIAlertAction) in
                self.position = .prone
                self.photoButton?.isUserInteractionEnabled = true
                self.updateCurrentTargetInfoUI()
            }))
            positonAlert.addAction(UIAlertAction(title: "Offhand", style: .default, handler: { (action:UIAlertAction) in
                self.position = .offhand
                self.photoButton?.isUserInteractionEnabled = true
                self.updateCurrentTargetInfoUI()
            }))
            positonAlert.addAction(UIAlertAction(title: "Kneeling", style: .default, handler: { (action:UIAlertAction) in
                self.position = .kneeling
                self.photoButton?.isUserInteractionEnabled = true
                self.updateCurrentTargetInfoUI()
            }))
            positonAlert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: nil))
            self.present(positonAlert, animated: true, completion: nil)
            
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func showTakenPhoto() {
        disableTakePhotoUI()
        DispatchQueue.main.async {
            self.view.addSubview(self.takenImageBorder)
            self.takenImageView.image = self.image
            self.view.addSubview(self.takenImageView)
            
            self.saveTargetButton?.isHidden = false
            self.deleteTakenImageButton?.isHidden = false
            self.view.bringSubview(toFront: self.saveTargetButton!)
            self.view.bringSubview(toFront: self.deleteTakenImageButton!)
            
            self.photoButton?.isUserInteractionEnabled = false
        }
    }
    
    //    MARK: Photo Output Delegates
    @available(iOS 11.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let loadedImage = UIImage(data: data) else {return}
        image = loadedImage
        showTakenPhoto()
    }
    @available(iOS 10.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        
        guard let data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer!, previewPhotoSampleBuffer: previewPhotoSampleBuffer), let loadedImage = UIImage(data: data) else {return}
        image = loadedImage
        showTakenPhoto()
        
    }
    
    @objc func image (_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error { //Error
            print("Error saving photo!")
            let errorAlert = UIAlertController(title: "Error!", message: error.localizedDescription, preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
            self.present(errorAlert, animated: true, completion: nil)
            self.takenImageView.removeFromSuperview()
            self.takenImageBorder.removeFromSuperview()
            self.saveTargetButton?.isHidden = true
            return
        }
        
        //Success
        print("Successfully Added Image to Photo Album!")
        let successAlert = UIAlertController(title: "Saved!", message: "The Image Has Been Saved", preferredStyle: .alert)
        successAlert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        self.present(successAlert, animated: true, completion: nil)
        self.takenImageView.removeFromSuperview()
        self.takenImageBorder.removeFromSuperview()
        self.saveTargetButton?.isHidden = true
//        addNewTargetAndSaveCSV()
    }
    
    @objc func saveImage() {
        let alert = UIAlertController(title: "Targets Score", message: "Type the score of the target", preferredStyle: .alert)
        alert.addTextField { (textField:UITextField) in
            textField.placeholder = "Target Score"
            textField.keyboardType = .numberPad
            textField.tag = 52
        }
        
        alert.addAction(UIAlertAction(title: "Save Target", style: .default, handler: { (action:UIAlertAction) in
            alert.textFields?.forEach({ (textField: UITextField) in
                if textField.tag == 52 {
//                    var placeholder: PHObjectPlaceholder?
                    if textField.hasText { self.score = Int(textField.text!)!}
                    
                    self.saveImageToDocumentsFolder(image: self.image!)
//                    PHPhotoLibrary.shared().performChanges({
//                        let request = PHAssetChangeRequest.creationRequestForAsset(from: self.image!)
//                        placeholder = request.placeholderForCreatedAsset
//                    }, completionHandler: { (success, error) in
//                        if success {
//                            print("Successfully Added Image to Photo Album!")
//
//                            //Hide the Taken Photo UI
//                            self.clearTakenPhotoUI()
//
//                            let successAlert = UIAlertController(title: "Saved!", message: "The Image Has Been Saved", preferredStyle: .alert)
//                            successAlert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
//                            self.present(successAlert, animated: true, completion: nil)
//
//                            let fetchOptions = PHFetchOptions()
//                            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
//                            fetchOptions.fetchLimit = 1
//
//                            let fetchResult: PHFetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [(placeholder?.localIdentifier)!], options: fetchOptions)
//                            //let fetchResult: PHFetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
//                            if fetchResult.count > 0 {
//                                let requestOptions = PHImageRequestOptions()
//                                requestOptions.isSynchronous = true
//                                requestOptions.version = .original
//
//                                PHImageManager.default().requestImageData(for: fetchResult.object(at: 0) as PHAsset, options: requestOptions, resultHandler: { (data, uti, orientation, info) in
//                                    let filePathURL = info!["PHImageFileURLKey"] as! URL
//                                    print("Name: \(filePathURL.lastPathComponent)")
//                                    self.image_path = "/\(filePathURL.lastPathComponent)"
//                                    self.addNewTargetAndSaveCSV()
//                                })
//
//                            }
//                        }else {
//                            print("Error saving photo!")
//
//                            //Hide the Taken Photo UI
//                            self.clearTakenPhotoUI()
//
//                            let errorAlert = UIAlertController(title: "Error!", message: "Error saving photo to photo library", preferredStyle: .alert)
//                            errorAlert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
//                            self.present(errorAlert, animated: true, completion: nil)
//                        }
//                    })
                    //                        UIImageWriteToSavedPhotosAlbum(image, self, #selector(ViewController.image(_:didFinishSavingWithError:contextInfo:)), nil)
                }
            })
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
            //Hide the Taken Photo UI
            self.clearTakenPhotoUI()
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc func deleteTakenPhoto() {
        clearTakenPhotoUI()
    }
    
    func addNewTargetAndSaveCSV() {
        csvText += "\n\(image_path),\(score),\(position),\(total_score),\(week)"
        do {
            try csvText.write(to: fileURL!, atomically: true, encoding: .utf8)
        } catch {
            print("Error Writing File")
            //Hide the Taken Photo UI
            self.clearTakenPhotoUI()
            
            let errorAlert = UIAlertController(title: "Error!", message: "There was an error while writing to the .csv file.", preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
            self.present(errorAlert, animated: true, completion: nil)
        }
        print("Finished With saving csv file")
    }

    func saveImageToDocumentsFolder(image: UIImage) {
        createDatasetDirectory()
    
        let imageName = getImageName()
        
        let destinationURL = path?.appendingPathComponent("dataset").appendingPathComponent(imageName)
        print("Path: ", destinationURL?.lastPathComponent ?? "ERROR")
        image_path = "/\((destinationURL?.lastPathComponent)!)"
        if let imageData = UIImageJPEGRepresentation(image, 1.0),
            !FileManager.default.fileExists(atPath: (destinationURL?.path)!) {
            do {
                try imageData.write(to: destinationURL!)
                
                //Hide the Taken Photo UI
                self.clearTakenPhotoUI()
                
                lastImageNumber += 1
                updateCurrentTargetInfoUI()
                CSVparser.addRow(imagePath: image_path, score: "\(score)", position: "\(position)", totalScore: "\(total_score)", week: "\(week)")
                
                let successAlert = UIAlertController(title: "Saved!", message: "The Image Has Been Saved", preferredStyle: .alert)
                successAlert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                self.present(successAlert, animated: true, completion: nil)
                
                self.addNewTargetAndSaveCSV()
            }catch {
                print("Error saving file: ", error.localizedDescription)
                let errorAlert = UIAlertController(title: "Error!", message: "There was an error while saving the image. \(error.localizedDescription)", preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                self.present(errorAlert, animated: true, completion: nil)
            }
        }
    }
    
    func createDatasetDirectory() {
        let directoryPath = path?.appendingPathComponent("dataset")
        var isDir : ObjCBool = false
        if !FileManager.default.fileExists(atPath: (directoryPath?.path)!, isDirectory: &isDir) {//Create the directory
            do {
                try FileManager.default.createDirectory(at: directoryPath!, withIntermediateDirectories: true, attributes: nil)
            }catch {
                print("Error creating directory", error.localizedDescription)
            }
        }
    }
    
}


extension UIImageView
{
    func roundCornersForAspectFit(radius: CGFloat)
    {
        if let image = self.image {
            
            //calculate drawingRect
            let boundsScale = self.bounds.size.width / self.bounds.size.height
            let imageScale = image.size.width / image.size.height
            
            var drawingRect: CGRect = self.bounds
            
            if boundsScale > imageScale {
                drawingRect.size.width =  drawingRect.size.height * imageScale
                drawingRect.origin.x = (self.bounds.size.width - drawingRect.size.width) / 2
            } else {
                drawingRect.size.height = drawingRect.size.width / imageScale
                drawingRect.origin.y = (self.bounds.size.height - drawingRect.size.height) / 2
            }
            let path = UIBezierPath(roundedRect: drawingRect, cornerRadius: radius)
            let mask = CAShapeLayer()
            mask.path = path.cgPath
            self.layer.mask = mask
        }
    }
}









