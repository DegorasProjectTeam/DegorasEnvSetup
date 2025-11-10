
#include <thread>
#include <chrono>

#include "model.h"

Model::Model(QObject *parent)
    : QObject{parent}
    , var1_("Empty")
    , var2_("Empty")
{}

void Model::shortActionReq()
{
    var1_ = QString::number(std::rand());
    var2_ = QString::number(std::rand());

    emit var1TextChanged(var1_);
    emit var2TextChanged(var2_);
}

void Model::longActionReq()
{
    emit statusTextChanged("Processing long action...");

    std::this_thread::sleep_for(std::chrono::seconds(5));

    var1_ = QString::number(std::rand());
    var2_ = QString::number(std::rand());

    emit var1TextChanged(var1_);
    emit var2TextChanged(var2_);

    emit statusTextChanged("Waiting user input...");
}
