/*
 * return number of days between two dates
 * @params dateString1 date #1 to be compared
 *         dateString2 date #2 to be compared
 */
export function getDiffDays(dateString1, dateString2) {
    if (!dateString1 || ! dateString2) return 0;
    //set two date variables
    let date1 = new Date(dateString1), date2 = new Date(dateString2);
    // To calculate the time difference of two dates
    var diffInTime = date2.getTime() - date1.getTime();
    // To calculate the no. of days between two dates
    return Math.ceil(diffInTime / (1000 * 3600 * 24));
}
