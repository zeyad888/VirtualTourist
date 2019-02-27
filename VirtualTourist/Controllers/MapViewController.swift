//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Zeyad AlHusainan on 26/02/2019.
//  Copyright © 2019 Zeyad. All rights reserved.
//

import UIKit
import MapKit
import CoreData
import CoreLocation


class MapViewController: UIViewController, NSFetchedResultsControllerDelegate, UIGestureRecognizerDelegate, MKMapViewDelegate  {
    
    var dataController : DataController!
    var pins:[Pin]!
    var pinToPass: Pin?
    var fetchResultVC: NSFetchedResultsController<Pin>!
    var locationManager = CLLocationManager.init()


    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        uploadFetchedPins()
        setUp()
        mapView.delegate = self
        
    }
    
    func setUp() {
        
        let fetchRequest: NSFetchRequest<Pin> = Pin.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "latitude", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        fetchResultVC = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchResultVC.delegate = self
//        self.mapView.delegate = self
        do {
            try fetchResultVC.performFetch()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }
    

    @IBAction func addPin(_ sender: UILongPressGestureRecognizer) {
        if sender.state != .began {return}
        let location: CGPoint = sender.location(in: self.mapView)
        let locationCoordinate: CLLocationCoordinate2D = self.mapView.convert(location, toCoordinateFrom: self.mapView)
        addAnnotationOnLocation(pointedCoordinate: locationCoordinate)
        
        let pin = Pin(context: dataController.viewContext)
        pin.latitude = locationCoordinate.latitude
        pin.longitude = locationCoordinate.longitude
        print("Save: ", pin)
        pins.append(pin)
        pinToPass = pin
        try? dataController.viewContext.save()

    }
    
    
    func addAnnotationOnLocation(pointedCoordinate: CLLocationCoordinate2D) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = pointedCoordinate
        mapView.addAnnotation(annotation)
        
    }
    
    
    func uploadFetchedPins(){
//        guard (fetchResultVC.fetchedObjects?.count) != nil else { return }
        pins = dataController.fetchPins(viewContext: dataController.viewContext)

        for pin in pins {
            let pinAdd = MKPointAnnotation()
            pinAdd.coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
            mapView.addAnnotation(pinAdd)
            pins.append(pin)
        }
        mapView.showAnnotations(mapView.annotations, animated: true)
        
//        for pin in pins {
//            let annotation = MKPointAnnotation()
//            annotation.coordinate = CLLocationCoordinate2D (latitude: pin.latitude, longitude: pin.longitude)
//            self.mapView.addAnnotation(annotation)
//        }
    
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? PhotoAlbumViewController {
            vc.pin = self.pinToPass!
            print("Passed!")
        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation else {
            return
        }
        //
        // 1
        let optionMenu = UIAlertController(title: nil, message: "Choose Option", preferredStyle: .actionSheet)
        let deleteAction = UIAlertAction(title: "Delete this pin", style: .default) { (action) in
            let pinToDelete = self.pins.first(where: { $0.latitude == view.annotation?.coordinate.latitude && $0.longitude == view.annotation?.coordinate.longitude})
            self.mapView.removeAnnotation(annotation)
            self.dataController.viewContext.delete(pinToDelete!)
            try? self.dataController.viewContext.save()
        }
        
        let editAction = UIAlertAction(title: "View photos", style: .default) { (action) in
            // Go to Album
            if self.pins.isEmpty {
                self.performSegue(withIdentifier: "PhotoAlbumViewController", sender: self)
                print("First Pin!")
                return
            }
            self.pinToPass = self.pins.first(where: { $0.latitude == view.annotation?.coordinate.latitude && $0.longitude == view.annotation?.coordinate.longitude})
            
            self.performSegue(withIdentifier: "PhotoAlbumViewController", sender: self)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        optionMenu.addAction(editAction)
        optionMenu.addAction(deleteAction)
        optionMenu.addAction(cancelAction)
        self.present(optionMenu, animated: true, completion: nil)
        
        //
        
        mapView.deselectAnnotation(annotation, animated: true)
        print("\(#function) lat \(annotation.coordinate.latitude) lon \(annotation.coordinate.longitude)")
    }
}
