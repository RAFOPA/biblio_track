function createCrudService(Model, { fields, defaultSort = { _id: -1 }, softDeleteField = null } = {}) {
  if (!Model || !Array.isArray(fields) || fields.length === 0) {
    throw new TypeError('El servicio CRUD requiere un modelo y una lista explícita de campos permitidos.');
  }
  const pickAllowedFields = (input = {}) => Object.fromEntries(
    fields.filter((field) => Object.hasOwn(input, field)).map((field) => [field, input[field]]),
  );
  return {
    async list({ filter = {}, page = 1, limit = 50 } = {}) {
      const safePage = Math.max(1, Number.parseInt(page, 10) || 1);
      const safeLimit = Math.min(100, Math.max(1, Number.parseInt(limit, 10) || 50));
      const [items, total] = await Promise.all([
        Model.find(filter).sort(defaultSort).skip((safePage - 1) * safeLimit).limit(safeLimit).lean(),
        Model.countDocuments(filter),
      ]);
      return { items, total, page: safePage, limit: safeLimit };
    },
    async getById(id) {
      return Model.findById(id).lean();
    },
    async create(input) {
      return Model.create(pickAllowedFields(input));
    },
    async updateById(id, input, { filter = {} } = {}) {
      return Model.findOneAndUpdate({ _id: id, ...filter }, { $set: pickAllowedFields(input) }, {
        new: true,
        runValidators: true,
      }).lean();
    },
    async deleteById(id) {
      if (softDeleteField) {
        return Model.findByIdAndUpdate(id, { $set: { [softDeleteField]: false } }, { new: true }).lean();
      }
      return Model.findByIdAndDelete(id).lean();
    },
  };
}

module.exports = { createCrudService };
