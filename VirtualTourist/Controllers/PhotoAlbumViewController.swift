//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Zeyad AlHusainan on 26/02/2019.
//  Copyright © 2019 Zeyad. All rights reserved.
//

import UIKit
import MapKit
import CoreData


class PhotoAlbumViewController: UIViewController, MKMapViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    
    var dataController : DataController!
    var pin: Pin!
    var fetchResultVC: NSFetchedResultsController<Image>!

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        collectionView.dataSource = self
        setUpMapView()
        setUp()
        getImages()
    }
    
    
    fileprivate func setUpMapView() {
        let location = CLLocationCoordinate2D(latitude: pin.latitude,
                                              longitude: pin.longitude)
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        let region = MKCoordinateRegion(center: location, span: span)
        mapView.setRegion(region, animated: true)
        let annotation = MKPointAnnotation()
        annotation.coordinate = location
        mapView.addAnnotation(annotation)
    }
    
    func setUp() {
        let fetchRequest: NSFetchRequest<Image> = Image.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "url", ascending: true)
        let predicate = NSPredicate(format: "pin = %@", pin!)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [sortDescriptor]
        dataController = (UIApplication.shared.delegate as! AppDelegate).dataController
        fetchResultVC = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchResultVC.delegate = self
        do {
            try fetchResultVC.performFetch()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
        print("End Fetch!: ", fetchResultVC.fetchedObjects?.count)
    }
    
    func getImages() {
        
        guard ((fetchResultVC.fetchedObjects?.count) == 0) else {
            indicator.isHidden = true
            collectionView.reloadData()
            return
        }
        indicator.startAnimating()
        FlickerAPI.searchByLatLon(latitude: pin.latitude, longitude: pin.longitude, pin: pin) { (error, done) in
            if done {
                DispatchQueue.main.async {
                    print("Done: ", done)
                    self.indicator.stopAnimating()
                    self.indicator.isHidden = true
                }
            }
            else {
//
                self.indicator.isHidden = true
                let controller = UIAlertController()
                controller.title = "error"
                controller.message = "Connection failed!"
                
                let okAction = UIAlertAction(title: "ok", style: UIAlertAction.Style.default) { action in self.dismiss(animated: true, completion: nil)
                }
                
                controller.addAction(okAction)
                self.present(controller, animated: true, completion: nil)
            }
        }
        
    }
    
    
    @IBAction func newPhotos(_ sender: Any) {
        deleteAllData()
        self.indicator.isHidden = false
        self.indicator.startAnimating()
        FlickerAPI.searchByLatLon(latitude: pin.latitude, longitude: pin.longitude, pin: pin) { (error, done) in
            if done {
                DispatchQueue.main.async {
                    self.indicator.isHidden = true
                    self.indicator.stopAnimating()
                }
            }
            else {
                print("Error: ", error!)
            }
        }
    }
    
    func deleteAllData() {
        let fetchRequest: NSFetchRequest<Image> = Image.fetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        do {
            let results = try dataController.viewContext.fetch(fetchRequest)
            for object in results {
                guard let objectData = object as? NSManagedObject else {continue}
                dataController.viewContext.delete(objectData)
            }
            print("We delete all object in image")
        } catch let error {
            print("Detele all data in entity error :", error)
        }
    }
    



    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print(fetchResultVC.fetchedObjects?.count ?? 0)
        return self.fetchResultVC.fetchedObjects?.count ?? 0
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath as IndexPath) as! PhotoCollectionViewCell
        let image = fetchResultVC.object(at: indexPath)
        
        if let imageData = fetchResultVC.object(at: indexPath).imageData {
            cell.imageView.image = UIImage(data: imageData)
        } else {
            cell.imageView.image = UIImage(named: "img-placeholder.png")
            FlickerAPI.downloadImage(imagePath: image.url!) { (data, error) in
                if let imageData = data {
                    DispatchQueue.main.async {
                        cell.imageView.image = UIImage(data: imageData)
                        image.imageData = imageData
                        try? self.dataController.viewContext.save()
                    }
                }
            }
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {

        let optionMenu = UIAlertController(title: nil, message: "Choose Option", preferredStyle: .actionSheet)
        let deleteAction = UIAlertAction(title: "Delete", style: .default) { (action) in
            let imageToDelete = self.fetchResultVC.object(at: indexPath)
            self.dataController.viewContext.delete(imageToDelete)
            try? self.dataController.viewContext.save()
        }
        
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        optionMenu.addAction(deleteAction)
        optionMenu.addAction(cancelAction)
        self.present(optionMenu, animated: true, completion: nil)
        
       
    }
    
    
}

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        collectionView.reloadData()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // TODO: finish updating the table view
        collectionView.reloadData()
        
    }


}
