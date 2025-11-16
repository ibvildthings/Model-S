/**
 * Driver Model
 * Represents a driver in the system
 */

class Driver {
  constructor(id, name, lat, lng, vehicleType = 'Standard', rating = 4.8) {
    this.id = id;
    this.name = name;
    this.location = { lat, lng };
    this.vehicleType = vehicleType;
    this.rating = rating;
    this.available = true;
    this.currentRideId = null;
    this.vehicleModel = this.generateVehicleModel();
    this.licensePlate = this.generateLicensePlate();
  }

  generateVehicleModel() {
    const models = [
      'Toyota Camry',
      'Honda Accord',
      'Tesla Model 3',
      'Toyota Prius',
      'Honda Civic',
      'Ford Fusion',
      'Chevrolet Malibu',
      'Nissan Altima'
    ];
    return models[Math.floor(Math.random() * models.length)];
  }

  generateLicensePlate() {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    let plate = '';

    // Format: ABC-1234
    for (let i = 0; i < 3; i++) {
      plate += letters.charAt(Math.floor(Math.random() * letters.length));
    }
    plate += '-';
    for (let i = 0; i < 4; i++) {
      plate += numbers.charAt(Math.floor(Math.random() * numbers.length));
    }

    return plate;
  }

  assignRide(rideId) {
    this.available = false;
    this.currentRideId = rideId;
  }

  completeRide() {
    this.available = true;
    this.currentRideId = null;
  }

  updateLocation(lat, lng) {
    this.location = { lat, lng };
  }

  toJSON() {
    return {
      id: this.id,
      name: this.name,
      vehicleType: this.vehicleType,
      vehicleModel: this.vehicleModel,
      licensePlate: this.licensePlate,
      rating: this.rating,
      location: this.location,
      available: this.available
    };
  }
}

module.exports = Driver;
